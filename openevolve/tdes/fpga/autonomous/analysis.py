"""Generate AAAI results tables from metrics.json.

Usage:
    python -m openevolve.tdes.fpga.autonomous.analysis --input tdes_aaai_results/metrics.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict


def load_metrics(path):
    with open(path) as f:
        return json.load(f)


def table1_solve_rate(metrics):
    """Table 1: Solve rate per condition × design."""
    conditions = sorted(set(v.get("condition", "?") for v in metrics.values()))
    designs = sorted(set(v.get("design", "?") for v in metrics.values()))

    # Group by (design, condition) -> list of solved booleans
    grid = defaultdict(list)
    for key, val in metrics.items():
        d = val.get("design", "?")
        c = val.get("condition", "?")
        grid[(d, c)].append(val.get("solved", False))

    print("=" * 80)
    print("TABLE 1: Solve Rate (solved/total seeds)")
    print("=" * 80)
    header = f"{'Design':<25}" + "".join(f"{c:>12}" for c in conditions)
    print(header)
    print("-" * len(header))

    totals = defaultdict(lambda: [0, 0])
    for d in designs:
        row = f"{d:<25}"
        for c in conditions:
            results = grid.get((d, c), [])
            solved = sum(results)
            total = len(results)
            totals[c][0] += solved
            totals[c][1] += total
            if total:
                row += f"{solved}/{total} ({100*solved/total:.0f}%)"
                row = row.ljust(25 + 12 * (conditions.index(c) + 1))
            else:
                row += f"{'--':>12}"
        print(row)

    print("-" * len(header))
    row = f"{'TOTAL':<25}"
    for c in conditions:
        s, t = totals[c]
        if t:
            row += f"{s}/{t} ({100*s/t:.0f}%)"
            row = row.ljust(25 + 12 * (conditions.index(c) + 1))
        else:
            row += f"{'--':>12}"
    print(row)
    print()


def table2_llm_efficiency(metrics):
    """Table 2: LLM calls and wall-clock time per condition."""
    conditions = sorted(set(v.get("condition", "?") for v in metrics.values()))

    stats = defaultdict(lambda: {"calls": [], "wall": [], "solved": 0, "total": 0})
    for val in metrics.values():
        c = val.get("condition", "?")
        stats[c]["calls"].append(val.get("llm_calls", 0))
        stats[c]["wall"].append(val.get("wall_seconds", 0))
        stats[c]["total"] += 1
        if val.get("solved"):
            stats[c]["solved"] += 1

    print("=" * 80)
    print("TABLE 2: LLM Efficiency")
    print("=" * 80)
    print(f"{'Condition':<15} {'Solve%':>8} {'Avg Calls':>12} {'Avg Wall(s)':>12} {'Cells':>8}")
    print("-" * 60)
    for c in conditions:
        s = stats[c]
        avg_calls = sum(s["calls"]) / len(s["calls"]) if s["calls"] else 0
        avg_wall = sum(s["wall"]) / len(s["wall"]) if s["wall"] else 0
        solve_pct = 100 * s["solved"] / s["total"] if s["total"] else 0
        print(f"{c:<15} {solve_pct:>7.0f}% {avg_calls:>12.1f} {avg_wall:>12.1f} {s['total']:>8}")
    print()


def table3_decomposition(metrics):
    """Table 3: Decomposition details for C3/C4/C5."""
    decomp_conditions = ["C3", "C4", "C5"]
    by_design = defaultdict(list)

    for val in metrics.values():
        if val.get("condition") in decomp_conditions:
            d = val.get("design", "?")
            by_design[d].append(val)

    if not by_design:
        return

    print("=" * 80)
    print("TABLE 3: Decomposition Details")
    print("=" * 80)
    for d in sorted(by_design):
        entries = by_design[d]
        modules = None
        for e in entries:
            if e.get("decomp_modules"):
                modules = e["decomp_modules"]
                break
        if modules:
            print(f"{d}: {len(modules)} modules — {', '.join(modules)}")
    print()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    args = parser.parse_args()

    metrics = load_metrics(args.input)
    print(f"\nLoaded {len(metrics)} experiment cells from {args.input}\n")

    table1_solve_rate(metrics)
    table2_llm_efficiency(metrics)
    table3_decomposition(metrics)


if __name__ == "__main__":
    main()
