"""
Experiment 5 — Convergence-efficiency analysis (no new LLM calls).

Aggregates the metrics from Experiments 1-3 into the paper's efficiency figures:

  * ``fig1_cumulative_solve.csv`` — for each condition, the cumulative number of
    designs solved as a function of cumulative LLM calls spent (the "money plot":
    a method that reaches the same solve count at fewer calls is more efficient).
  * ``fig2_speedup.csv`` — per-design ``calls_to_solve(single_agent) /
    calls_to_solve(tdes_full)`` on designs both solved.
  * ``fig3_crossover.json`` — pooled complementary-coverage crossover statistics
    per design (attempts, accepts, mean test-lift).
  * a printed summary table (solve rate, median calls, median calls-to-solve).

    python -m openevolve.tdes.fpga.experiments.convergence \
        --inputs tdes_fpga_results/metrics_exp1.json \
                 tdes_fpga_results/metrics_exp2.json \
                 tdes_fpga_results/metrics_exp3.json \
        --outdir tdes_fpga_results/exp5
"""

from __future__ import annotations

import argparse
import json
import os
from typing import List

from openevolve.tdes.fpga import metrics
from openevolve.tdes.fpga.experiments import _explib


def _load_all(paths: List[str]) -> List[metrics.RunMetrics]:
    rows: List[metrics.RunMetrics] = []
    for p in paths:
        if os.path.exists(p):
            rows.extend(metrics.load_metrics(p))
    return rows


def _cumulative_solve_csv(rows, path) -> None:
    conditions = sorted({m.condition for m in rows})
    with open(path, "w", encoding="utf-8") as f:
        f.write("condition,cumulative_calls,cumulative_solved\n")
        for c in conditions:
            solved = sorted(
                (m for m in rows if m.condition == c and m.solved and m.calls_to_solve),
                key=lambda m: m.calls_to_solve,
            )
            cum_calls = 0
            for i, m in enumerate(solved, start=1):
                cum_calls += m.calls_to_solve
                f.write(f"{c},{cum_calls},{i}\n")


def _speedup_csv(rows, path) -> None:
    sp = _explib.speedup_rows(rows, fast="tdes_full", slow="single_agent")
    with open(path, "w", encoding="utf-8") as f:
        f.write("design,tdes_full_calls,single_agent_calls,speedup\n")
        for r in sp:
            f.write(
                f"{r['design']},{r['fast_calls']:.0f},{r['slow_calls']:.0f},{r['speedup']:.3f}\n"
            )
    return sp


def _crossover_json(rows, path) -> None:
    by_design = {}
    for m in rows:
        if m.condition != "tdes_full" or not m.crossover:
            continue
        d = by_design.setdefault(
            m.design, {"pairs_considered": 0, "attempts": 0, "accepted": 0, "lift": 0.0}
        )
        c = m.crossover
        d["pairs_considered"] += c.get("pairs_considered", 0)
        d["attempts"] += c.get("attempts", 0)
        d["accepted"] += c.get("accepted", 0)
        d["lift"] += c.get("mean_lift", 0) * c.get("accepted", 0)
    for d in by_design.values():
        d["mean_lift"] = round(d["lift"] / d["accepted"], 3) if d["accepted"] else 0.0
        del d["lift"]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(by_design, f, indent=2)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Exp 5: convergence-efficiency analysis")
    p.add_argument(
        "--inputs",
        nargs="*",
        default=[
            "tdes_fpga_results/metrics_exp1.json",
            "tdes_fpga_results/metrics_exp2.json",
            "tdes_fpga_results/metrics_exp3.json",
        ],
    )
    p.add_argument("--outdir", default="tdes_fpga_results/exp5")
    args = p.parse_args(argv)

    _explib.setup_logging()
    os.makedirs(args.outdir, exist_ok=True)
    rows = _load_all(args.inputs)
    if not rows:
        print("no metrics found in", args.inputs)
        return 1

    _cumulative_solve_csv(rows, os.path.join(args.outdir, "fig1_cumulative_solve.csv"))
    sp = _speedup_csv(rows, os.path.join(args.outdir, "fig2_speedup.csv"))
    _crossover_json(rows, os.path.join(args.outdir, "fig3_crossover.json"))

    conditions = sorted({m.condition for m in rows})
    print("\n# Experiment 5 — convergence-efficiency analysis\n")
    print(_explib.render_efficiency(rows, conditions))
    if sp:
        mean_speedup = sum(r["speedup"] for r in sp) / len(sp)
        print(
            f"\nMean calls-to-solve speedup (single_agent / tdes_full) over "
            f"{len(sp)} jointly-solved designs: {mean_speedup:.2f}x"
        )
    print(f"\nfigures -> {os.path.abspath(args.outdir)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
