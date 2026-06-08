"""
Run the efficiency demo with a real LLM: evolve the 4-multiplier complex
multiplier into a provably-equivalent 3-multiplier design (the AlphaEvolve-TPU
analog — a functionally-identical, smaller arithmetic circuit that passes formal
verification).

    OSS_CAD_SUITE_ROOT=... ANTHROPIC_API_KEY=... \
    python -m openevolve.tdes.fpga.efficiency_demo.run_demo \
        --config openevolve/tdes/fpga/experiments/configs/anthropic_sonnet.yaml
"""

from __future__ import annotations

import argparse
import logging
import os
import sys

from openevolve.tdes.controller import TDESController
from openevolve.tdes.fpga import synthesis
from openevolve.tdes.fpga.config import FPGAConfig
from openevolve.tdes.fpga.efficiency_demo.efficiency_suite import EfficiencySuite
from openevolve.tdes.fpga.mutation import VerilogLLMMutator
from openevolve.tdes.types import Candidate

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

logger = logging.getLogger(__name__)
_DESIGNS = os.path.join(os.path.dirname(__file__), "designs")


def _read(name: str) -> str:
    with open(os.path.join(_DESIGNS, f"{name}.v"), encoding="utf-8") as f:
        return f.read()


def _mults(src: str) -> int:
    r = synthesis.rtl_cell_counts({"cmul": src}, top_module="cmul")
    return synthesis.multiplier_count(r) if r.ok else -1


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="TDES-FPGA efficiency demo (LLM)")
    p.add_argument("--config", required=True)
    p.add_argument("--pop", type=int, default=4)
    p.add_argument("--gens", type=int, default=6)
    p.add_argument("--mul-budget", type=int, default=3)
    p.add_argument("--output", default="tdes_fpga_results/efficiency_demo")
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    config = FPGAConfig.from_yaml(args.config)
    config.pop_size = args.pop
    config.max_generations = args.gens
    config.diff_based = False
    config.output_dir = args.output
    os.makedirs(args.output, exist_ok=True)

    from openevolve.llm.ensemble import LLMEnsemble

    ensemble = LLMEnsemble(config.llm.llm.models)
    mutator = VerilogLLMMutator(ensemble, diff_based=False)

    golden = _read("golden")
    seed_src = _read("seed")
    suite = EfficiencySuite(
        module="cmul",
        golden_source=golden,
        top="cmul",
        mul_budget=args.mul_budget,
        timeout=config.suite_timeout,
    )
    seed = Candidate(modules={"cmul": seed_src})

    print(
        f"\nSeed: {_mults(seed_src)} multipliers. Goal: provably-equivalent design "
        f"with <= {args.mul_budget} multipliers.\n"
    )

    controller = TDESController(seed, suite, mutator, config)
    result = controller.run()

    best_src = result.best.modules["cmul"]
    best_mults = _mults(best_src)
    solved = result.best.vector.total_passes == len(suite.tests)

    print("\n" + "=" * 64)
    print(f"  result: {result.best.vector.summary()}")
    print(f"  seed multipliers:  {_mults(seed_src)}")
    print(f"  best multipliers:  {best_mults}")
    print(f"  formally equivalent: {result.best.vector.results['unit:equiv'].passed}")
    print(f"  SOLVED (equivalent AND under budget): {solved}")
    print(
        f"  generations: {result.generations_run}" f"{' (escalated)' if result.escalated else ''}"
    )
    print("=" * 64)
    print(f"\nBest design written to {os.path.join(args.output, 'best', 'cmul.py')}")
    return 0 if solved else 1


if __name__ == "__main__":
    raise SystemExit(main())
