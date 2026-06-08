"""
Experiment 4 — Full mechanism ablation on the hierarchical designs.

Isolates each TDES mechanism on the Exp-2 designs. Conditions:
  * tdes_full        — all mechanisms
  * tdes_no_crossover — remove complementary-coverage crossover (primary)
  * tdes_no_memory   — remove negative-exemplar memory
  * tdes_scalar      — flatten the hierarchy to scalar pass-count fitness
  * tdes_no_cegis    — remove structured CEGIS feedback (pass/fail only)
  * single_agent     — single-candidate iterative repair (floor)
3 seeds; diverse module scheduling; one module fixed per candidate per
generation. Model: Sonnet.

    export ANTHROPIC_API_KEY=... OSS_CAD_SUITE_ROOT=...
    python -m openevolve.tdes.fpga.experiments.run_exp4_ablation \
        --config .../configs/anthropic_sonnet.yaml --seeds 0 1 2
"""

from __future__ import annotations

import argparse
import os

from openevolve.tdes.fpga import metrics
from openevolve.tdes.fpga.experiments import _explib, hierarchical_archx

CONDITIONS = [
    "tdes_full",
    "tdes_no_crossover",
    "tdes_no_memory",
    "tdes_scalar",
    "tdes_no_cegis",
    "single_agent",
]


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Exp 4: full mechanism ablation (Sonnet)")
    p.add_argument("--config")
    p.add_argument("--designs", nargs="*", default=None)
    p.add_argument("--conditions", nargs="*", default=CONDITIONS)
    p.add_argument("--seeds", nargs="*", type=int, default=[0, 1, 2])
    p.add_argument("--gens", type=int, default=6)
    p.add_argument("--pop", type=int, default=6)
    p.add_argument("--scripted", action="store_true")
    p.add_argument("--out", default="tdes_fpga_results/metrics_exp4.json")
    args = p.parse_args(argv)

    _explib.setup_logging()
    config = _explib.load_config(args.config, gens=args.gens, pop=args.pop, mutate_one=True)
    designs = args.designs or hierarchical_archx.DESIGNS

    results = _explib.run(
        "hier",
        designs,
        args.conditions,
        config,
        seeds=args.seeds,
        out=args.out,
        controller="diverse",
        scripted=args.scripted,
        decompose=False,
        require_usable=True,
    )

    print("\n# Experiment 4 — full mechanism ablation (Sonnet)\n")
    print("## Table: per-mechanism solve rate + efficiency\n")
    print(metrics.render_table1(results, args.conditions))
    print()
    print(_explib.render_efficiency(results, args.conditions))
    print(f"\nraw metrics -> {os.path.abspath(args.out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
