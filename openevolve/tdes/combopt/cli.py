"""
CLI for TDES-CombOpt.

    python tdes-combopt-run.py --problem mis \
        [--config cfg.yaml] [--gens 6] [--pop 6] [--scripted] [--no-system]

Loads a combinatorial problem into a (seed portfolio, CombOptTestSuite) pair,
builds a mutator (LLM by default; ``--scripted`` uses the offline reference
mutator), and runs the TDES generational loop via ``DiverseScheduleController``.
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from typing import Optional

from openevolve.tdes.combopt import ablation, benchmark_loader
from openevolve.tdes.combopt.mutation import HeuristicLLMMutator
from openevolve.tdes.combopt.problems import PROBLEMS
from openevolve.tdes.config import TDESConfig


def _build_mutator(problem: str, config: TDESConfig):
    if config.llm is None or not config.llm.llm.models:
        raise SystemExit("LLM mode requires a config with an `llm:` section (or use --scripted).")
    from openevolve.llm.ensemble import LLMEnsemble

    ensemble = LLMEnsemble(config.llm.llm.models)
    return HeuristicLLMMutator(ensemble, problem, diff_based=config.diff_based)


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="tdes-combopt-run", description="TDES for NP-hard heuristics"
    )
    parser.add_argument("--problem", required=True, choices=list(PROBLEMS))
    parser.add_argument("--config", help="YAML config (tdes: and llm: sections)")
    parser.add_argument("--gens", type=int)
    parser.add_argument("--pop", type=int)
    parser.add_argument("--scripted", action="store_true", help="Use the offline reference mutator")
    parser.add_argument("--no-system", action="store_true", help="Drop the SYSTEM hybrid test")
    parser.add_argument("--output")
    args = parser.parse_args(argv)

    config = TDESConfig.from_yaml(args.config) if args.config else TDESConfig()
    if args.gens is not None:
        config.max_generations = args.gens
    if args.pop is not None:
        config.pop_size = args.pop
    if args.output:
        config.output_dir = args.output
    if config.mutate_modules_per_candidate is None:
        config.mutate_modules_per_candidate = 1

    logging.basicConfig(
        level=getattr(logging, config.log_level.upper(), logging.INFO),
        format="%(asctime)s [%(levelname)s] %(message)s",
    )

    seed, suite, scripted_mutator = benchmark_loader.load_problem(
        args.problem, with_mutator=True, include_system=not args.no_system
    )
    mutator = scripted_mutator if args.scripted else _build_mutator(args.problem, config)

    controller = ablation.DiverseScheduleController(seed, suite, mutator, config)
    result = controller.run()

    print("\n=== TDES-CombOpt result ===")
    print(f"problem         : {args.problem}")
    print(f"generations run : {result.generations_run}")
    print(f"escalated       : {result.escalated}")
    print(f"best            : {result.best.vector.summary()}")
    print(f"crossover       : {controller.crossover_stats.as_dict()}")
    print(f"output          : {os.path.abspath(config.output_dir)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
