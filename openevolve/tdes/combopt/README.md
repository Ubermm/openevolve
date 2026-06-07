# TDES-CombOpt: evolving NP-hard heuristics that beat exact solvers under budget

An **additive** TDES layer (sibling of `tdes/fpga/`) that evolves *heuristics* for
NP-hard combinatorial problems and composes them with a downstream **exact
solver** — the FunSearch / AlphaEvolve pattern: *evolve the priority function,
never the solution; a deterministic evaluator owns correctness.*

The base TDES controller / selection / crossover / memory are reused **unchanged**
(duck-typed against the suite). Only the test runner is swapped.

## What is evolved

A candidate is a **portfolio** `{instance_class: priority_source}` — one
`priority(v, graph) -> float` per instance class (`sparse` / `dense` /
`clustered`). A fixed, trusted harness calls `priority` and **guarantees a
feasible solution**, recomputing the objective exactly. The LLM only supplies the
ranking heuristic.

* **MIS** (maximum independent set): greedy construction — repeatedly take the
  highest-priority available vertex, remove it and its neighbors. The classical
  baseline is static min-degree; an *adaptive residual* min-degree heuristic
  beats it.
* **Max-Cut**: bounded 1-flip local search — at each step the evolved `priority`
  is the **move selector** over the currently improving vertices (gains exposed
  in `graph.state["gain"]`). The classical baseline is steepest ascent.

## Hierarchical tests (the `TestVector` levels)

* **UNIT** — the class-`c` heuristic matches/beats the classical baseline on a
  single class-`c` instance.
* **INTEGRATION** — per class, the heuristic matches/beats the baseline in
  aggregate over a held-out batch (generalization).
* **SYSTEM** — the portfolio's solutions, used to **warm-start CP-SAT**, make the
  hybrid (`max(heuristic, warm-solver)`) beat the **cold** solver under the same
  fixed *deterministic* budget. This is the headline "heuristic + downstream
  exact solver beats the solver alone under budget" gate.

Multi-module portfolios give complementary-coverage **crossover** a natural
target: a candidate strong on one class and weak on another passes a strict
subset of the unit tests, and crossover grafts class specialists into a complete
portfolio.

## Running

```bash
pip install ortools            # CP-SAT exact solver (networkx optional)

# offline (no API key): scripted reference heuristic
python tdes-combopt-run.py --problem mis --scripted --gens 5

# real LLM
ANTHROPIC_API_KEY=... python tdes-combopt-run.py --problem maxcut \
    --config openevolve/tdes/combopt/experiments/configs/anthropic_sonnet.yaml

# method comparison (TDES vs single-agent vs pass@5)
python -m openevolve.tdes.combopt.experiments.run_combopt \
    --config .../configs/anthropic_sonnet.yaml --problems mis maxcut \
    --conditions tdes_full single_agent pass5 --seeds 0 1

# offline diagnostics / ablations (no API key)
python -m openevolve.tdes.combopt._validate mis
python -m openevolve.tdes.combopt.experiments.crossover_ablation mis
```

Tests: `python -m unittest openevolve.tdes.combopt.tests.test_combopt` (gated on
`ortools`; no API key needed). See `experiments/RESULTS.md` for measured results.

**Do not modify base `tdes/*` files** — extend via subclass/composition, as this
layer does.
