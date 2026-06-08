"""
Experiment 3 — Complexity scaling on ArchXBench Level 2-3.

Goal: test TDES on harder designs with natural (but not explicitly named) module
structure, and show where the advantage scales and where it degrades to
single-agent. Conditions: ``tdes_full`` vs ``tdes_no_crossover`` vs
``single_agent``; 3 seeds; Sonnet (with an optional Opus spot-check on the
hardest designs via --config-opus / a second invocation).

ArchXBench ships no reference RTL, so usability gating is unavailable: runs use
the native testbench as the system test (require_usable=False, decompose attempts
a golden-expression hierarchy for combinational designs and otherwise falls back
to the native testbench). Designs whose testbench is clocked or not
machine-parseable will read as unsolved for *every* method (the verdict parser is
failure-evidence-first) rather than producing a false pass — those are reported,
not hidden.

    export ANTHROPIC_API_KEY=... OSS_CAD_SUITE_ROOT=...
    python -m openevolve.tdes.fpga.experiments.run_exp3_scaling \
        --config .../configs/anthropic_sonnet.yaml --seeds 0 1 2
"""

from __future__ import annotations

import argparse
import os

from openevolve.tdes.fpga import metrics
from openevolve.tdes.fpga.experiments import _explib

# Level-2 (pipelined integer / AES round) and Level-3 (iterative FP) designs.
DEFAULT_DESIGNS = [
    "aes128_single_round",  # L2 — SubBytes/ShiftRows/MixColumns/AddRoundKey
    "cla_32bit_pipe",  # L2 — pipelined carry-lookahead adder
    "wallace_tree_mult_pipe",  # L2 — pipelined Wallace-tree multiplier
    "fp_adder",  # L3 — floating-point adder
    "fp_multiplier",  # L3 — floating-point multiplier
]
CONDITIONS = ["tdes_full", "tdes_no_crossover", "single_agent"]


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Exp 3: ArchXBench L2-3 scaling")
    p.add_argument("--config")
    p.add_argument("--designs", nargs="*", default=None)
    p.add_argument("--conditions", nargs="*", default=CONDITIONS)
    p.add_argument("--seeds", nargs="*", type=int, default=[0, 1, 2])
    p.add_argument("--gens", type=int, default=6)
    p.add_argument("--pop", type=int, default=4)
    p.add_argument("--out", default="tdes_fpga_results/metrics_exp3.json")
    args = p.parse_args(argv)

    _explib.setup_logging()
    config = _explib.load_config(args.config, gens=args.gens, pop=args.pop)
    designs = args.designs or DEFAULT_DESIGNS

    results = _explib.run(
        "archxbench",
        designs,
        args.conditions,
        config,
        seeds=args.seeds,
        out=args.out,
        controller="auto",
        scripted=False,
        decompose=True,
        require_usable=False,
    )

    print("\n# Experiment 3 — ArchXBench Level 2-3 scaling (Sonnet)\n")
    print("## Table 1: method comparison\n")
    print(metrics.render_table1(results, args.conditions))
    print("\n## Efficiency (LLM calls)\n")
    print(_explib.render_efficiency(results, args.conditions))
    print(f"\nraw metrics -> {os.path.abspath(args.out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
