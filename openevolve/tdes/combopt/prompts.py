"""
Prompt construction for evolving combinatorial-optimization *heuristics*.

A candidate module is a single ``priority(v, graph) -> float`` function that the
LLM improves. The prompt explains the fixed harness contract (so the model knows
exactly what it is ranking and what graph API is available) but, per the CEGIS
constraint, never reveals the test source — only the natural-language
description, the failing instance, and the error.
"""

from __future__ import annotations

from typing import List

from openevolve.tdes.types import FeedbackTuple

SYSTEM_MESSAGE_COMBOPT = """You are an expert in combinatorial optimization and \
algorithm design, operating inside a Test-Driven Evolutionary Synthesis loop. \
You improve ONE heuristic at a time so that a portfolio of heuristics passes more \
of a hierarchical test suite (unit, integration, system).

Each heuristic is a single Python function `priority(v, graph) -> float`. It is \
called by a FIXED, trusted harness that guarantees a feasible solution and scores \
it exactly — you only supply the ranking heuristic, you never construct the \
solution yourself. Higher `priority` means the harness prefers vertex `v`.

Rules:
- Write a pure, deterministic, side-effect-free function. No imports, no I/O, no \
randomness, no global state. It must be fast (called many times per instance).
- Use only the `graph` API described in the task. Do not assume test internals; \
fix the behavior the failing tests describe.
- A constant or near-constant priority is a weak baseline — exploit graph \
structure (degrees, neighbor relationships, the harness state) to rank well.
- You may be shown previously attempted approaches that FAILED; do not repeat \
them. Reason about what structural signal you have not yet used."""


# Per-problem contract shown to the model: what the harness does and the graph API.
PROBLEM_CONTRACTS = {
    "mis": """## Problem: Maximum Independent Set (maximize set size)

The harness builds an independent set greedily: while vertices remain available, \
it selects the AVAILABLE vertex with the highest `priority(v, graph)`, adds it to \
the set, and removes it and all its neighbors. Your heuristic decides which \
vertex to take next. A strong heuristic prefers vertices that "cost" little — \
e.g. low *residual* degree (few still-available neighbors).

`graph` API:
- `graph.n` — number of vertices.
- `graph.neighbors(v)` — set of neighbor vertex ids of `v`.
- `graph.degree(v)` — static degree of `v` in the full graph.
- `graph.state['available']` — the set of vertices still available this run \
(updated by the harness as it builds the set). Reading it lets you compute \
residual degree: `sum(1 for u in graph.neighbors(v) if u in graph.state['available'])`.""",
    "maxcut": """## Problem: Maximum Cut (maximize total weight of edges across the partition)

The harness runs a 1-flip local search from the all-zero partition. At each step \
it computes every vertex's `gain` (the cut-weight increase from flipping that \
vertex to the other side) and considers only the IMPROVING vertices (gain > 0). \
It then flips the improving vertex with the highest `priority(v, graph)`. Your \
heuristic is the move selector; a strong rule is steepest ascent (largest gain \
first), possibly with smarter tie-breaking.

`graph` API:
- `graph.n` — number of vertices.
- `graph.neighbors(v)` — set of neighbor vertex ids of `v`.
- `graph.weight(u, v)` — weight of edge (u, v) (0 if none).
- `graph.degree(v)` — degree of `v`.
- `graph.state['gain'][v]` — current gain of flipping `v` (the cut increase). \
Only vertices with gain > 0 are passed to you.
- `graph.state['side'][v]` — current side (0/1) of `v`.""",
}


DIFF_INSTRUCTIONS = """Respond with one or more SEARCH/REPLACE diff blocks that \
edit the function. Use exactly this format:

<<<<<<< SEARCH
# exact existing lines to find
=======
# replacement lines
>>>>>>> REPLACE

Then, on a final line, give a one-line summary of your approach prefixed with \
"SUMMARY:"."""


REWRITE_INSTRUCTIONS = """Respond with the complete, rewritten function inside a \
single fenced code block:

```python
def priority(v, graph):
    ...
```

Then, on a final line, give a one-line summary of your approach prefixed with \
"SUMMARY:"."""


def build_generation_prompt(problem_name: str, module_name: str) -> str:
    """From-scratch generation prompt (no feedback) for the pass@k baseline."""
    contract = PROBLEM_CONTRACTS[problem_name]
    return f"""{contract}

# Task
Write a strong `priority(v, graph)` heuristic specialized for the \
`{module_name}` instance class. Exploit graph structure; do not return a constant.

Respond with the complete function inside a single fenced code block:

```python
def priority(v, graph):
    ...
```
"""


def render_feedback(feedback: List[FeedbackTuple]) -> str:
    if not feedback:
        return "(no failing tests for this heuristic)"
    return "\n".join(f.render() for f in feedback)


def build_user_prompt(
    *,
    problem_name: str,
    module_name: str,
    module_source: str,
    feedback: List[FeedbackTuple],
    memory_text: str,
    diff_based: bool,
    generation: int,
) -> str:
    """Build the user message for mutating one class-specialized heuristic."""
    instructions = DIFF_INSTRUCTIONS if diff_based else REWRITE_INSTRUCTIONS
    contract = PROBLEM_CONTRACTS[problem_name]
    memory_block = (
        f"\n# Previously attempted approaches that FAILED (avoid these)\n{memory_text}\n"
        if memory_text
        else ""
    )
    return f"""# Generation {generation}

{contract}

# Heuristic to improve: specialized for the `{module_name}` instance class

```python
{module_source}
```

# Failing tests (description, failing input, error) — test source withheld
{render_feedback(feedback)}
{memory_block}
# Task
Improve the `priority` function above (it is the `{module_name}`-class heuristic) \
so it passes the failing tests while keeping the tests it already passes green. \
Exploit graph structure; do not just return a constant.

{instructions}
"""
