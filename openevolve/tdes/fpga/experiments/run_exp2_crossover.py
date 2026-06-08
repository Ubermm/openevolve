"""
Experiment 2 — Crossover showcase on *published* hierarchical ArchXBench designs.

The money experiment. Using the real multi-module harness
(``hierarchical_archx``), each design (comparator-8bit, decoder-3to8, mux4to1,
demux-1to4, carry_select_adder_32bit) is a genuine ``{TOP, SUB}`` problem whose
3-tier suite makes complementary-coverage crossover able to fire on a *published*
benchmark. Conditions: ``tdes_full`` vs ``tdes_no_crossover`` vs ``single_agent``
vs ``pass5``; 3 seeds; diverse module scheduling; one module fixed per candidate
per generation. Model: Sonnet.

    export ANTHROPIC_API_KEY=... OSS_CAD_SUITE_ROOT=...
    python -m openevolve.tdes.fpga.experiments.run_exp2_crossover \
        --config openevolve/tdes/fpga/experiments/configs/anthropic_sonnet.yaml \
        --seeds 0 1 2
"""

from __future__ import annotations

import argparse
import os

from openevolve.tdes.fpga import metrics
from openevolve.tdes.fpga.experiments import _explib, hierarchical_archx

CONDITIONS = ["tdes_full", "tdes_no_crossover", "single_agent", "pass5"]


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Exp 2: hierarchical crossover showcase (Sonnet)")
    p.add_argument("--config")
    p.add_argument("--designs", nargs="*", default=None)
    p.add_argument("--conditions", nargs="*", default=CONDITIONS)
    p.add_argument("--seeds", nargs="*", type=int, default=[0, 1, 2])
    p.add_argument("--gens", type=int, default=6)
    p.add_argument("--pop", type=int, default=6)
    p.add_argument("--scripted", action="store_true")
    p.add_argument("--out", default="tdes_fpga_results/metrics_exp2.json")
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

    print("\n# Experiment 2 — crossover on published hierarchical ArchXBench designs (Sonnet)\n")
    print("## Table 1: method comparison\n")
    print(metrics.render_table1(results, args.conditions))
    print("\n## Table 2: complementary-coverage crossover (tdes_full)\n")
    print(metrics.render_table2([m for m in results if m.condition == "tdes_full"]))
    print("\n## Efficiency: calls-to-first-solution\n")
    print(_explib.render_efficiency(results, args.conditions))
    print("\n## Per-module solve timeline (tdes_full)\n")
    print(_explib.render_module_timeline(results, "tdes_full"))
    print(f"\nraw metrics -> {os.path.abspath(args.out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
