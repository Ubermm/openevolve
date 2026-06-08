"""
Per-generation source snapshotting for TDES-CombOpt — the paper artifact that
shows *how the evolved code changed*, generation by generation.

The base runs persist only score trajectories (``result.json`` history) and the
final ``best/`` source, so the actual generation-by-generation code diffs are
lost.  This module adds an **additive** snapshotting controller (subclass of the
suite-agnostic :class:`DiverseScheduleController`; the base ``tdes/*`` files are
untouched) that dumps every population candidate's source each generation, plus
a generator that turns one clean run into a tracked ``evolution_log/`` with
unified diffs along the best-of-generation lineage.

    ANTHROPIC_API_KEY=... python -m openevolve.tdes.combopt.experiments.snapshot \
        --config openevolve/tdes/combopt/experiments/configs/anthropic_sonnet.yaml \
        --problems mis maxcut --seed 0
"""

from __future__ import annotations

import argparse
import difflib
import json
import logging
import os
import sys
from typing import Dict, List, Optional

from openevolve.tdes import selection
from openevolve.tdes.combopt import ablation, benchmark_loader
from openevolve.tdes.combopt.experiments import runner
from openevolve.tdes.combopt.mutation import HeuristicLLMMutator
from openevolve.tdes.config import TDESConfig

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

logger = logging.getLogger(__name__)


# --------------------------------------------------------------------------- #
# Snapshotting controller                                                      #
# --------------------------------------------------------------------------- #
class _SnapshotMixin:
    """Dump every candidate's source each generation into ``<output_dir>/lineage``.

    Hooks the base controller's ``_record_history`` (called once per generation,
    including the terminal solved/stagnated generation) so it captures the full
    population — ranked, with each candidate's score summary — without touching
    the evolutionary loop itself.
    """

    def _record_history(self, gen, population, *, stagnated=False, solved=False):  # type: ignore[override]
        super()._record_history(gen, population, stagnated=stagnated, solved=solved)
        ranked = selection.rank(population)
        gen_dir = os.path.join(self.config.output_dir, "lineage", f"gen_{gen:02d}")
        summaries = []
        for rank, cand in enumerate(ranked):
            cand_dir = os.path.join(gen_dir, f"{rank:02d}_{cand.id}")
            os.makedirs(cand_dir, exist_ok=True)
            for name, source in cand.modules.items():
                with open(os.path.join(cand_dir, f"{name}.py"), "w", encoding="utf-8") as f:
                    f.write(source)
            summaries.append(
                {
                    "rank": rank,
                    "id": cand.id,
                    "generation": getattr(cand, "generation", gen),
                    "origin": (cand.metadata or {}).get("origin", "seed"),
                    "score_key": list(cand.vector.score_key) if cand.vector else None,
                    "summary": cand.vector.summary() if cand.vector else None,
                }
            )
        with open(os.path.join(gen_dir, "generation.json"), "w", encoding="utf-8") as f:
            json.dump(
                {"generation": gen, "stagnated": stagnated, "solved": solved, "population": summaries},
                f,
                indent=2,
            )


class SnapshottingController(_SnapshotMixin, ablation.DiverseScheduleController):
    """DiverseScheduleController that also snapshots per-generation source."""


# --------------------------------------------------------------------------- #
# Run one clean cell with snapshotting                                         #
# --------------------------------------------------------------------------- #
def run_snapshot_cell(
    problem: str,
    config: TDESConfig,
    *,
    seed: int,
    ensemble,
    out_dir: str,
) -> Dict:
    """Run a single TDES-full cell with per-generation snapshotting.

    Returns a dict describing the run (output dir, trajectory, final source).
    """
    seed_cand, suite, _ref = benchmark_loader.load_problem(problem, with_mutator=False)
    cfg = runner._clone_config(config, seed)
    cfg.output_dir = out_dir
    os.makedirs(out_dir, exist_ok=True)

    mutator = HeuristicLLMMutator(ensemble, problem, diff_based=cfg.diff_based)
    controller = SnapshottingController(seed_cand, suite, mutator, cfg)
    result = controller.run()

    return {
        "problem": problem,
        "seed": seed,
        "out_dir": out_dir,
        "seed_modules": dict(seed_cand.modules),
        "solved": result.best.vector.total_passes == len(suite.tests),
        "total_tests": len(suite.tests),
        "final_summary": result.best.vector.summary(),
        "generations_run": result.generations_run,
        "escalated": result.escalated,
        "history": result.history,
        "crossover": controller.crossover_stats.as_dict(),
    }


# --------------------------------------------------------------------------- #
# Evolution-log generation (tracked artifact)                                  #
# --------------------------------------------------------------------------- #
def _best_of_generation(lineage_dir: str) -> List[Dict]:
    """Return [{generation, dir, summary, modules:{cls:source}}] for rank-0 each gen."""
    gens = []
    if not os.path.isdir(lineage_dir):
        return gens
    for gen_name in sorted(os.listdir(lineage_dir)):
        gen_dir = os.path.join(lineage_dir, gen_name)
        meta_path = os.path.join(gen_dir, "generation.json")
        if not os.path.isfile(meta_path):
            continue
        with open(meta_path, encoding="utf-8") as f:
            meta = json.load(f)
        pop = meta.get("population", [])
        if not pop:
            continue
        best = pop[0]
        best_dir = os.path.join(gen_dir, f"{best['rank']:02d}_{best['id']}")
        modules = {}
        if os.path.isdir(best_dir):
            for fn in sorted(os.listdir(best_dir)):
                if fn.endswith(".py"):
                    with open(os.path.join(best_dir, fn), encoding="utf-8") as f:
                        modules[fn[:-3]] = f.read()
        gens.append(
            {
                "generation": meta["generation"],
                "summary": best.get("summary"),
                "origin": best.get("origin"),
                "modules": modules,
            }
        )
    return gens


def _udiff(a: str, b: str, fromfile: str, tofile: str) -> str:
    return "".join(
        difflib.unified_diff(
            a.splitlines(keepends=True),
            b.splitlines(keepends=True),
            fromfile=fromfile,
            tofile=tofile,
        )
    )


def emit_evolution_log(run: Dict, log_root: str) -> str:
    """Write a tracked per-run evolution record: best-of-generation source +
    seed→gen unified diffs per class.  Returns the run's log directory."""
    problem, seed = run["problem"], run["seed"]
    run_log = os.path.join(log_root, f"{problem}_seed{seed}")
    os.makedirs(run_log, exist_ok=True)

    lineage = _best_of_generation(os.path.join(run["out_dir"], "lineage"))
    seed_modules = run["seed_modules"]
    classes = sorted(seed_modules)

    # Per-class diff chains (seed -> gen1-best -> ... -> final-best).
    diffs_dir = os.path.join(run_log, "diffs")
    os.makedirs(diffs_dir, exist_ok=True)
    for cls in classes:
        chunks = []
        prev_src, prev_label = seed_modules[cls], "seed"
        for g in lineage:
            cur = g["modules"].get(cls, prev_src)
            label = f"gen{g['generation']:02d}"
            d = _udiff(prev_src, cur, f"{cls}@{prev_label}", f"{cls}@{label}")
            if d.strip():
                chunks.append(f"### {prev_label} → {label}  ({g['summary']})\n\n```diff\n{d}\n```\n")
            prev_src, prev_label = cur, label
        with open(os.path.join(diffs_dir, f"{cls}.md"), "w", encoding="utf-8") as f:
            f.write(f"# `{cls}` heuristic evolution — {problem} seed {seed}\n\n")
            f.write("\n".join(chunks) if chunks else "_no source change recorded_\n")

    # Final source snapshot (tracked copy of best/, which lives in a gitignored run dir).
    final_dir = os.path.join(run_log, "final")
    os.makedirs(final_dir, exist_ok=True)
    final_modules = lineage[-1]["modules"] if lineage else {}
    for cls, src in (final_modules or seed_modules).items():
        with open(os.path.join(final_dir, f"{cls}.py"), "w", encoding="utf-8") as f:
            f.write(src)

    # If the run escalated, keep the human-in-the-loop package (failing tests +
    # negative memory) alongside the lineage — it explains *why* evolution stalled.
    esc_src = os.path.join(run["out_dir"], "escalation.json")
    if os.path.isfile(esc_src):
        with open(esc_src, encoding="utf-8") as f:
            esc = json.load(f)
        with open(os.path.join(run_log, "escalation.json"), "w", encoding="utf-8") as f:
            json.dump(esc, f, indent=2)

    # Run summary markdown.
    traj = [h.get("best_summary") for h in run["history"]]
    with open(os.path.join(run_log, "README.md"), "w", encoding="utf-8") as f:
        f.write(f"# Evolution log — {problem}, seed {seed}\n\n")
        f.write(
            f"- solved: **{run['solved']}** ({run['final_summary']}, "
            f"{run['total_tests']} tests)\n"
            f"- generations run: {run['generations_run']}"
            f"{' (escalated)' if run['escalated'] else ''}\n"
            f"- crossover: {run['crossover']}\n\n"
        )
        f.write("## Best-of-generation trajectory\n\n")
        f.write("| gen | best (rank-0) summary | origin |\n|---|---|---|\n")
        f.write(f"| 0 | seed: constant `priority = 0.0` | seed |\n")
        for g in lineage:
            f.write(f"| {g['generation']} | {g['summary']} | {g['origin']} |\n")
        f.write("\n## Per-class seed→final diffs\n\n")
        for cls in classes:
            f.write(f"- [`{cls}`](diffs/{cls}.md)\n")
    return run_log


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="TDES-CombOpt per-generation evolution snapshot")
    p.add_argument("--config", required=True)
    p.add_argument("--problems", nargs="*", default=["mis", "maxcut"])
    p.add_argument("--seed", type=int, default=0)
    p.add_argument(
        "--run-root",
        default="tdes_combopt_results/snapshot",
        help="gitignored dir for raw per-generation lineage",
    )
    p.add_argument(
        "--log-root",
        default="openevolve/tdes/combopt/experiments/evolution_log",
        help="tracked dir for the curated diffs + EVOLUTION_LOG.md",
    )
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    config = TDESConfig.from_yaml(args.config)
    ensemble = runner.build_ensemble(config)

    os.makedirs(args.log_root, exist_ok=True)
    index = []
    for problem in args.problems:
        out_dir = os.path.join(args.run_root, f"{problem}_seed{args.seed}")
        print(f"\n=== snapshot: {problem} seed {args.seed} ===")
        run = run_snapshot_cell(problem, config, seed=args.seed, ensemble=ensemble, out_dir=out_dir)
        run_log = emit_evolution_log(run, args.log_root)
        index.append((problem, args.seed, run))
        print(f"  -> {run['final_summary']}  (log: {run_log})")

    # Top-level index.
    with open(os.path.join(args.log_root, "EVOLUTION_LOG.md"), "w", encoding="utf-8") as f:
        f.write("# TDES-CombOpt evolution log\n\n")
        f.write(
            "Per-generation source diffs along the best-of-generation lineage, for "
            "the documented runs. Each run starts from the deliberately weak seed "
            "(`def priority(v, graph): return 0.0` for every instance class) so the "
            "diffs show the full discovery, from no class knowledge to the final "
            "portfolio that warm-starts CP-SAT past the cold solver.\n\n"
        )
        f.write("| run | solved | final | gens | crossover acc/att |\n|---|---|---|---|---|\n")
        for problem, seed, run in index:
            xo = run["crossover"]
            f.write(
                f"| [{problem} seed {seed}]({problem}_seed{seed}/README.md) | "
                f"{run['solved']} | {run['final_summary']} | {run['generations_run']} | "
                f"{xo.get('accepted', 0)}/{xo.get('attempts', 0)} |\n"
            )
    print(f"\nWrote index: {os.path.join(args.log_root, 'EVOLUTION_LOG.md')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
