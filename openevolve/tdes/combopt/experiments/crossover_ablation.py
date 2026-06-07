"""
Crossover-necessity ablation for TDES-CombOpt (offline, no LLM).

Runs ``tdes_full`` (crossover on) vs ``tdes_no_crossover`` (off) on the
units+integration suite (``include_system=False``) with the scripted reference
mutator, ``DiverseScheduleController``, and one module fixed per candidate per
generation. Under a generation budget below the module count, a single lineage
cannot fix all three class heuristics, so only complementary-coverage crossover
can combine partial portfolios into a complete one — the controlled result that
crossover is *necessary*, not merely helpful.

    python -m openevolve.tdes.combopt.experiments.crossover_ablation mis
    python -m openevolve.tdes.combopt.experiments.crossover_ablation maxcut
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


def run_condition(problem, condition, gens, seed):
    seed_cand, suite, mutator = benchmark_loader.load_problem(
        problem, with_mutator=True, include_system=False
    )
    kwargs, _ = ablation.CONDITIONS[condition]
    cfg = TDESConfig(
        pop_size=6,
        max_generations=gens,
        sandbox=False,
        suite_timeout=120,
        mutate_modules_per_candidate=1,
        random_seed=100 + seed,
        output_dir=f"tdes_combopt_results/xover_{problem}/{condition}/seed_{seed}",
    )
    ctrl = ablation.DiverseScheduleController(seed_cand, suite, mutator, cfg, **kwargs)
    res = ctrl.run()
    solved = res.best.vector.total_passes == len(suite.tests)
    return {
        "passes": res.best.vector.total_passes,
        "total": len(suite.tests),
        "solved": solved,
        "gens": res.generations_run,
        "xover": ctrl.crossover_stats.as_dict(),
    }


def main(problem: str) -> int:
    logging.basicConfig(level=logging.WARNING, format="%(message)s")
    seeds = [0, 1, 2]
    for label, gens in (("tight budget (gens=2)", 2), ("generous budget (gens=5)", 5)):
        print(f"\n=== {problem}: {label} ===")
        print(f"{'condition':20s} {'solved':>10s} {'mean passes':>12s} {'xover acc/att':>14s}")
        for cond in ("tdes_full", "tdes_no_crossover"):
            rows = [run_condition(problem, cond, gens, s) for s in seeds]
            nsolved = sum(r["solved"] for r in rows)
            mean_p = sum(r["passes"] for r in rows) / len(rows)
            tot = rows[0]["total"]
            acc = sum(r["xover"]["accepted"] for r in rows)
            att = sum(r["xover"]["attempts"] for r in rows)
            print(
                f"{cond:20s} {nsolved:>4d}/{len(seeds):<5d} {mean_p:>7.1f}/{tot:<4d} {acc:>6d}/{att:<7d}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "mis"))
