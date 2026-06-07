"""Offline end-to-end TDES integration + crossover demo (no LLM). Run:

    python -m openevolve.tdes.combopt._demo mis
    python -m openevolve.tdes.combopt._demo maxcut

Uses the scripted reference mutator and the DiverseScheduleController (randomized
per-candidate module order) so the population develops the complementary coverage
that crossover grafts. Confirms the base TDES controller/selection/crossover run
unchanged against the combopt suite, and reports crossover statistics.
"""

from __future__ import annotations

import logging
import sys

from openevolve.tdes.combopt import ablation, benchmark_loader
from openevolve.tdes.config import TDESConfig

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def main(name: str) -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    seed, suite, mutator = benchmark_loader.load_problem(name, with_mutator=True)
    cfg = TDESConfig(
        pop_size=6,
        max_generations=6,
        sandbox=False,  # in-process for a fast offline demo
        suite_timeout=120,
        mutate_modules_per_candidate=1,  # one class per candidate per gen -> diversity
        random_seed=7,
        output_dir=f"tdes_combopt_results/_demo_{name}",
    )
    controller = ablation.DiverseScheduleController(
        seed, suite, mutator, cfg, enable_crossover=True, enable_memory=True
    )
    result = controller.run()
    print(f"\n== {name} demo result ==")
    print(f"best: {result.best.vector.summary()}")
    print(f"generations run: {result.generations_run}, escalated: {result.escalated}")
    print(f"crossover stats: {controller.crossover_stats.as_dict()}")
    solved = result.best.vector.total_passes == len(suite.tests)
    print(f"solved: {solved}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "mis"))
