"""
Crossover-necessity ablation on the four-module datapath problem.

Compares ``tdes_full`` (complementary-coverage crossover ON) against
``tdes_no_crossover`` (crossover OFF) across seeds, with one module fixed per
candidate per generation and randomized module scheduling. Reports, per
condition: solve rate, mean generations-to-solve (over solved runs), and the
crossover attempt/success/lift statistics.

Because integration/system tests require multiple correct modules, a single
lineage needs ≥4 generations to fix all four modules alone; crossover combines
partial solutions to solve sooner — and under a tight generation budget, at all.

    export ANTHROPIC_API_KEY=...  OSS_CAD_SUITE_ROOT=...
    python -m openevolve.tdes.fpga.experiments.crossover_ablation \
        --config openevolve/tdes/fpga/experiments/configs/anthropic_sonnet.yaml \
        --seeds 0 1 2 --gens 6
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys

from openevolve.tdes.fpga.ablation import CONDITIONS, DiverseScheduleController
from openevolve.tdes.fpga.config import FPGAConfig
from openevolve.tdes.fpga.experiments import datapath_problem, runner
from openevolve.tdes.fpga.mutation import VerilogLLMMutator
from openevolve.tdes.types import Candidate

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

logger = logging.getLogger(__name__)
CONDITIONS_RUN = ["tdes_full", "tdes_no_crossover"]


def run_one(condition, seed, config, ensemble):
    kwargs, _ = CONDITIONS[condition]
    suite = datapath_problem.build_suite()
    cfg = FPGAConfig(**{k: getattr(config, k) for k in _cfg_fields(config)})
    cfg.random_seed = (config.random_seed or 0) + seed
    cfg.mutate_modules_per_candidate = 1
    cfg.output_dir = os.path.join(config.output_dir, f"{condition}_seed{seed}")
    controller = DiverseScheduleController(
        Candidate(modules=dict(datapath_problem.SEED)),
        suite,
        VerilogLLMMutator(ensemble, diff_based=cfg.diff_based),
        cfg,
        **kwargs,
    )
    result = controller.run()
    solved = result.best.vector.total_passes == len(suite.tests)
    return {
        "condition": condition,
        "seed": seed,
        "solved": solved,
        "passes": result.best.vector.total_passes,
        "tests": len(suite.tests),
        "gens_to_solve": result.generations_run if solved else None,
        "escalated": result.escalated,
        "crossover": controller.crossover_stats.as_dict(),
    }


def _cfg_fields(config):
    # copy the scalar FPGAConfig fields (skip llm, which we don't reconstruct)
    import dataclasses

    return [f.name for f in dataclasses.fields(config) if f.name != "llm"]


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="TDES-FPGA crossover-necessity ablation")
    p.add_argument("--config", required=True)
    p.add_argument("--seeds", nargs="*", type=int, default=[0, 1, 2])
    p.add_argument("--gens", type=int, default=6)
    p.add_argument("--pop", type=int, default=8)
    p.add_argument("--out", default="tdes_fpga_results/crossover_ablation.json")
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    config = FPGAConfig.from_yaml(args.config)
    config.max_generations = args.gens
    config.pop_size = args.pop
    ensemble = runner.build_ensemble(config)

    rows = []
    for condition in CONDITIONS_RUN:
        for seed in args.seeds:
            logger.info("=== %s seed=%s ===", condition, seed)
            try:
                rows.append(run_one(condition, seed, config, ensemble))
            except Exception as e:
                logger.warning("run %s seed=%s failed: %s", condition, seed, e)

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)

    print("\n## Crossover-necessity ablation (4-module datapath, Sonnet)\n")
    print("| Condition | solve rate | mean gens-to-solve | crossover accepted | mean lift |")
    print("|---|---|---|---|---|")
    for cond in CONDITIONS_RUN:
        cr = [r for r in rows if r["condition"] == cond]
        if not cr:
            continue
        solved = [r for r in cr if r["solved"]]
        sr = len(solved) / len(cr)
        mg = sum(r["gens_to_solve"] for r in solved) / len(solved) if solved else float("nan")
        acc = sum(r["crossover"]["accepted"] for r in cr)
        lifts = [r["crossover"]["mean_lift"] for r in cr if r["crossover"]["accepted"]]
        ml = sum(lifts) / len(lifts) if lifts else 0.0
        mg_s = f"{mg:.1f}" if solved else "—"
        print(f"| {cond} | {sr:.0%} ({len(solved)}/{len(cr)}) | {mg_s} | {acc} | +{ml:.2f} |")
    print(f"\nraw -> {os.path.abspath(args.out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
