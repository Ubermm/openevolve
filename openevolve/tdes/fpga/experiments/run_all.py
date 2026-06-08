"""
Orchestrate the full 5-experiment campaign, staged and partial-safe.

Runs (in order) Exp 1 (Haiku) -> Exp 2 (Sonnet) -> Exp 4 (Sonnet) -> Exp 3
(Sonnet) -> Exp 5 (analysis). Each experiment persists its own
``metrics_exp*.json`` incrementally, so the campaign is resumable: re-running
skips nothing destructive, and a crash leaves completed cells on disk. Use the
individual ``run_exp*.py`` drivers to run or re-run a single experiment.

    export ANTHROPIC_API_KEY=... OSS_CAD_SUITE_ROOT=...
    python -m openevolve.tdes.fpga.experiments.run_all \
        --haiku  openevolve/tdes/fpga/experiments/configs/anthropic_haiku.yaml \
        --sonnet openevolve/tdes/fpga/experiments/configs/anthropic_sonnet.yaml \
        --seeds 0 1 2
"""

from __future__ import annotations

import argparse

from openevolve.tdes.fpga.experiments import (
    convergence,
    run_exp1_baseline,
    run_exp2_crossover,
    run_exp3_scaling,
    run_exp4_ablation,
)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="TDES-FPGA full 5-experiment campaign")
    p.add_argument("--haiku", help="config for Exp 1 (breadth)")
    p.add_argument("--sonnet", help="config for Exp 2/3/4 (crossover + ablation)")
    p.add_argument("--seeds", nargs="*", type=str, default=["0", "1", "2"])
    p.add_argument("--skip", nargs="*", default=[], help="experiment numbers to skip, e.g. 3")
    args = p.parse_args(argv)

    seeds = args.seeds
    sonnet = ["--config", args.sonnet] if args.sonnet else []
    haiku = ["--config", args.haiku] if args.haiku else []

    if "1" not in args.skip:
        print("\n========== EXPERIMENT 1: RTLLM baseline (Haiku) ==========")
        run_exp1_baseline.main(haiku + ["--seeds", *seeds])
    if "2" not in args.skip:
        print("\n========== EXPERIMENT 2: hierarchical crossover (Sonnet) ==========")
        run_exp2_crossover.main(sonnet + ["--seeds", *seeds])
    if "4" not in args.skip:
        print("\n========== EXPERIMENT 4: mechanism ablation (Sonnet) ==========")
        run_exp4_ablation.main(sonnet + ["--seeds", *seeds])
    if "3" not in args.skip:
        print("\n========== EXPERIMENT 3: ArchXBench L2-3 scaling (Sonnet) ==========")
        run_exp3_scaling.main(sonnet + ["--seeds", *seeds])
    if "5" not in args.skip:
        print("\n========== EXPERIMENT 5: convergence analysis ==========")
        convergence.main([])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
