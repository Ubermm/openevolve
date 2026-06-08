"""
Shared plumbing for the paper's 5-experiment campaign (Exp 1-5).

Keeps each ``run_exp*.py`` driver thin: config loading + overrides, *incremental*
metrics persistence (so a multi-hour EDA-gated sweep is partial-safe), and the
extra table renderers (calls-to-solve, per-module solve timeline) the headline
tables need on top of ``metrics.render_table1/2``.
"""

from __future__ import annotations

import logging
import os
import statistics
import sys
from typing import Dict, List, Optional

from openevolve.tdes.fpga import metrics
from openevolve.tdes.fpga.config import FPGAConfig
from openevolve.tdes.fpga.experiments import runner

try:  # tables use ✓/✗; force UTF-8 so Windows consoles don't choke
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def setup_logging() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


def load_config(
    path: Optional[str], *, gens: int, pop: int, mutate_one: bool = False
) -> FPGAConfig:
    cfg = FPGAConfig.from_yaml(path) if path else FPGAConfig()
    cfg.max_generations = gens
    cfg.pop_size = pop
    if mutate_one:
        # One module fixed per candidate per generation — the regime in which a
        # single lineage cannot fix every module alone, so crossover earns its keep.
        cfg.mutate_modules_per_candidate = 1
    return cfg


class IncrementalWriter:
    """Persist metrics to JSON after every completed cell (resumable sweeps)."""

    def __init__(self, out_path: str):
        self.out_path = out_path
        self.results: List[metrics.RunMetrics] = []
        os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)

    def __call__(self, rm: metrics.RunMetrics) -> None:
        self.results.append(rm)
        metrics.save_metrics(self.results, self.out_path)


def run(
    benchmark: str,
    designs: List[str],
    conditions: List[str],
    config: FPGAConfig,
    *,
    seeds: List[int],
    out: str,
    controller: str = "auto",
    scripted: bool = False,
    decompose: bool = True,
    require_usable: bool = True,
) -> List[metrics.RunMetrics]:
    writer = IncrementalWriter(out)
    runner.run_matrix(
        benchmark,
        designs,
        conditions,
        config,
        seeds=seeds,
        scripted=scripted,
        decompose=decompose,
        require_usable=require_usable,
        controller=controller,
        on_result=writer,
    )
    return writer.results


# ---------------------------------------------------------------------------
# Extra renderers
# ---------------------------------------------------------------------------


def _median(xs: List[float]) -> Optional[float]:
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def render_efficiency(results: List[metrics.RunMetrics], conditions: List[str]) -> str:
    """Per-condition solve rate, median LLM calls, and median calls-to-solve."""
    lines = [
        "| Condition | solve rate | median calls (all) | median calls-to-solve (solved) |",
        "|---|---|---|---|",
    ]
    for c in conditions:
        rows = [m for m in results if m.condition == c]
        if not rows:
            continue
        sr = sum(1 for m in rows if m.solved) / len(rows)
        mc = _median([m.llm_calls for m in rows])
        cts = _median([m.calls_to_solve for m in rows if m.solved])
        mc_s = f"{mc:.0f}" if mc is not None else "—"
        cts_s = f"{cts:.0f}" if cts is not None else "—"
        lines.append(f"| {c} | {sr:.0%} | {mc_s} | {cts_s} |")
    return "\n".join(lines)


def render_module_timeline(results: List[metrics.RunMetrics], condition: str) -> str:
    """For one condition: the generation each module's tests first passed.

    Shows the complementary-coverage story — different lineages fixing different
    modules, then crossover combining them.
    """
    rows = [m for m in results if m.condition == condition and m.module_first_solved]
    if not rows:
        return "_(no per-module timeline recorded)_"
    lines = ["| Design | seed | per-module first-solved generation |", "|---|---|---|"]
    for m in sorted(rows, key=lambda r: (r.design, r.seed)):
        tl = ", ".join(f"{mod}@g{g}" for mod, g in sorted(m.module_first_solved.items()))
        lines.append(f"| {m.design} | {m.seed} | {tl} |")
    return "\n".join(lines)


def speedup_rows(results: List[metrics.RunMetrics], fast: str, slow: str) -> List[Dict]:
    """Per-design calls(slow)/calls(fast) speedup on designs both conditions solved."""
    out = []
    designs = sorted({m.design for m in results})
    for d in designs:
        f = [m for m in results if m.design == d and m.condition == fast and m.solved]
        s = [m for m in results if m.design == d and m.condition == slow and m.solved]
        if not f or not s:
            continue
        fc = _median([m.calls_to_solve for m in f])
        sc = _median([m.calls_to_solve for m in s])
        if fc and sc and fc > 0:
            out.append({"design": d, "fast_calls": fc, "slow_calls": sc, "speedup": sc / fc})
    return out
