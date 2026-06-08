"""
Experiment 1 — Baseline calibration on RTLLM v2 (single-module designs).

Goal: show the TDES engine is competitive and does not *hurt* on problems where
crossover cannot fire (RTLLM designs are single-module). Conditions:
``tdes_full`` vs ``single_agent`` vs ``pass5``; 3 seeds. Model: Haiku (breadth).
Crossover is expected to be inert here (nothing to graft) — its value is Exp 2.

    export ANTHROPIC_API_KEY=... OSS_CAD_SUITE_ROOT=...
    python -m openevolve.tdes.fpga.experiments.run_exp1_baseline \
        --config openevolve/tdes/fpga/experiments/configs/anthropic_haiku.yaml \
        --seeds 0 1 2
"""

from __future__ import annotations

import argparse
import os

from openevolve.tdes.fpga import metrics
from openevolve.tdes.fpga.experiments import _explib

# A 10-design RTLLM sample spanning Arithmetic/Control/Memory/Misc and difficulty.
# Unusable designs (reference fails under iverilog, or skeleton already passes) are
# auto-skipped by ``require_usable``; the rendered table reflects what actually ran.
DEFAULT_DESIGNS = [
    "adder_8bit",
    "adder_16bit",
    "multi_8bit",
    "multi_16bit",
    "div_16bit",
    "comparator_3bit",
    "accu",
    "right_shifter",
    "barrel_shifter",
    "adder_pipe_64bit",
]
CONDITIONS = ["tdes_full", "single_agent", "pass5"]


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Exp 1: RTLLM v2 baseline (Haiku)")
    p.add_argument("--config")
    p.add_argument("--designs", nargs="*", default=None)
    p.add_argument("--conditions", nargs="*", default=CONDITIONS)
    p.add_argument("--seeds", nargs="*", type=int, default=[0, 1, 2])
    p.add_argument("--gens", type=int, default=5)
    p.add_argument("--pop", type=int, default=4)
    p.add_argument("--scripted", action="store_true")
    p.add_argument("--out", default="tdes_fpga_results/metrics_exp1.json")
    args = p.parse_args(argv)

    _explib.setup_logging()
    config = _explib.load_config(args.config, gens=args.gens, pop=args.pop)
    designs = args.designs or DEFAULT_DESIGNS

    results = _explib.run(
        "rtllm",
        designs,
        args.conditions,
        config,
        seeds=args.seeds,
        out=args.out,
        controller="auto",
        scripted=args.scripted,
        decompose=True,
        require_usable=True,
    )

    print("\n# Experiment 1 — RTLLM v2 baseline (Haiku)\n")
    print("## Table 1: method comparison\n")
    print(metrics.render_table1(results, args.conditions))
    print("\n## Efficiency (LLM calls)\n")
    print(_explib.render_efficiency(results, args.conditions))
    print("\n## Crossover (expected inert on single-module designs)\n")
    print(metrics.render_table2(results))
    print(f"\nraw metrics -> {os.path.abspath(args.out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
