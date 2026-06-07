"""
Crossover-NECESSITY ablation with a real LLM (the controlled result that
complementary-coverage crossover is necessary, not merely helpful).

Setup mirrors the FPGA section-3 result: the units+integration suite
(``include_system=False``), one class repaired per candidate per generation
(``mutate_modules_per_candidate=1``) with ``DiverseScheduleController``, and a
generation budget below the module count. With imperfect LLM mutation no single
lineage can complete all three class heuristics under the budget, so only
crossover — combining two partial portfolios — can reach a complete one.

    ANTHROPIC_API_KEY=... python -m openevolve.tdes.combopt.experiments.run_crossover_llm \
        --config .../configs/anthropic_sonnet.yaml --problems mis maxcut --gens 2 --seeds 0 1 2
"""

from __future__ import annotations

import argparse
import logging
import sys

from openevolve.tdes.combopt.experiments import runner
from openevolve.tdes.config import TDESConfig

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="TDES-CombOpt crossover-necessity ablation (LLM)")
    p.add_argument("--config", required=True)
    p.add_argument("--problems", nargs="*", default=["mis", "maxcut"])
    p.add_argument("--gens", type=int, default=2)
    p.add_argument("--pop", type=int, default=6)
    p.add_argument("--seeds", nargs="*", type=int, default=[0, 1, 2])
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    config = TDESConfig.from_yaml(args.config)
    config.pop_size = args.pop
    config.max_generations = args.gens
    config.mutate_modules_per_candidate = 1  # one class per candidate per generation

    ensemble = runner.build_ensemble(config)
    loader_kwargs = {"include_system": False}

    for problem in args.problems:
        print(f"\n=== {problem}: crossover necessity (gens={args.gens}, 1 class/cand/gen) ===")
        print(f"{'condition':20s} {'solved':>8s} {'mean passes':>12s} {'xover acc/att':>14s}")
        for cond in ("tdes_full", "tdes_no_crossover"):
            rows = []
            for s in args.seeds:
                rm = runner.run_cell(
                    problem,
                    cond,
                    config,
                    seed=s,
                    ensemble=ensemble,
                    diverse_schedule=True,
                    loader_kwargs=loader_kwargs,
                )
                if rm is not None:
                    rows.append(rm)
            if not rows:
                continue
            nsolved = sum(r.solved for r in rows)
            mean_p = sum(r.total_passes for r in rows) / len(rows)
            tot = rows[0].total_tests
            acc = sum((r.crossover or {}).get("accepted", 0) for r in rows)
            att = sum((r.crossover or {}).get("attempts", 0) for r in rows)
            print(
                f"{cond:20s} {nsolved:>3d}/{len(rows):<4d} {mean_p:>7.1f}/{tot:<4d} {acc:>6d}/{att:<7d}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
