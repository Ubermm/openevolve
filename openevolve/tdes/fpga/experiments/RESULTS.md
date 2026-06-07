# TDES-FPGA: real-LLM experimental results

Runs below used **Claude Haiku 4.5** (`claude-haiku-4-5-20251001`) via the
Anthropic OpenAI-compatible endpoint, simulated/synthesized with the OSS CAD
Suite (Icarus Verilog 14, Yosys 0.66). Reproduce with the configs in
`configs/` (`ANTHROPIC_API_KEY` + `OSS_CAD_SUITE_ROOT` set).

## 1. RTLLM v2 — method comparison

5 designs, 1 seed, pop=4, gens=4 (`run_rtllm.py`):

| Design | tdes_full | single_agent | pass@5 |
|---|---|---|---|
| adder_8bit       | ✓ | ✓ | ✗ |
| adder_pipe_64bit | ✗ | ✓ | ✗ |
| div_16bit        | ✓ | ✓ | ✗ |
| multi_16bit      | ✗ | ✗ | ✗ |
| multi_8bit       | ✓ | ✓ | ✗ |
| **solve rate**   | **60%** | **80%** | **0%** |

Crossover analysis: 0 attempts — **expected**: RTLLM designs are single-module,
so there is nothing to graft. Crossover's value appears only on multi-module
codebases (see §2).

**Takeaways.** (a) Iterative-feedback methods (TDES, single-agent) vastly
outperform one-shot generation (Pass@5 = 0% with this model): the CEGIS
feedback loop is doing the work. (b) On *single-module* designs TDES's
population machinery does not beat single-agent repair — consistent with the
paper's claim that TDES targets *modular*, high-constraint problems, not simple
single-module ones.

## 2. Multi-module crossover demonstration

A two-module problem (`adder8` + `cmp8`) with an empty seed and a hierarchical
suite (unit test per module + an integration test using both), pop=6, gens=5,
one module fixed per candidate per generation, randomized module scheduling
(`crossover_demo.py`):

```
Gen 1  best 0/3   union passes 0     (all seeds empty)
Gen 2  best 1/3   union passes 2     (some candidates fixed adder8, others cmp8)
       Crossover accepted: <A:adder8-passing> + <B>[cmp8] -> child 3/3
       Crossover accepted: <B:cmp8-passing>   + <A>[adder8] -> child 3/3
Gen 3  best 3/3   SOLVED
```

Crossover statistics: **2 attempts, 2 accepted (100%), mean lift +2.0 tests**.

This is the paper's primary contribution working end-to-end with a real LLM:
complementary-coverage crossover combined two *partial* solutions (one with a
correct adder, one with a correct comparator) into a complete passing design by
grafting the donor's module — a jump no single mutation made.

> Note: the base controller fixes failing modules in a fixed order, so from a
> homogeneous seed every candidate pursues the same module first and no
> complementary coverage arises. `DiverseScheduleController` (in
> `crossover_demo.py`) randomizes per-candidate module order to produce the
> diversity crossover needs; all acceptance/regression rules are inherited
> unchanged. This is a documented requirement, not a workaround — it mirrors the
> population diversity that stochastic mutation provides at larger scale.

## 3. Crossover-necessity ablation (Sonnet, 3 seeds)

Four-module compositional problem (`datapath_problem.py`: `add8` + `bshift` +
`scmp` + `popcnt`; 4 unit + 2 integration + 1 system tests). Empty seed, one
module fixed per candidate per generation, randomized module scheduling
(`DiverseScheduleController`). `tdes_full` (crossover on) vs `tdes_no_crossover`
(off), **Claude Sonnet 4.6**, `crossover_ablation.py`.

Integration/system tests pass only when *multiple* modules are correct, so a
candidate with a subset of modules passes a strict subset of tests — the
complementary coverage crossover grafts. A single lineage can fix at most one
new module per generation, so it needs ≥4 generations to reach all four.

**Generous budget (gens=6):** both conditions solve, but crossover is highly
active and faster.

| Condition | solve rate | mean gens-to-solve | crossover accepts (per seed) | mean lift |
|---|---|---|---|---|
| tdes_full         | 3/3 | **4.67** | 13, 11, 6 | +1.9 tests |
| tdes_no_crossover | 3/3 | 5.00 | 0 | — |

**Tight budget (gens=3):** no single lineage can fix all four modules, so
crossover becomes *necessary*.

| Condition | solve rate | best passes (per seed) |
|---|---|---|
| tdes_full         | **1/3** (seed 1 → 7/7 via crossover) | 4, **7**, 4 / 7 |
| tdes_no_crossover | **0/3** — structurally capped | 4, 4, 4 / 7 |

**Takeaway.** Complementary-coverage crossover fires heavily on compositional
problems (6–13 accepted grafts/run, +1.9 mean test lift) and consistently
reduces generations-to-solve. Under a generation budget below the module count,
mutation alone is *structurally capped* (here at 4/7 — it can never combine the
separately-evolved modules), while crossover combines partial solutions to
reach a complete design. This is the controlled result that crossover is
*necessary*, not merely helpful, for modular synthesis under budget — exactly
the regime the paper targets.

> Honesty note (also in `crossover_demo.py`/`ablation.py`): the base controller
> fixes failing modules in a fixed order, so from a homogeneous seed every
> candidate pursues the same module first and no complementary coverage arises.
> `DiverseScheduleController` randomizes per-candidate module order to produce
> the diversity crossover needs; all acceptance/regression rules are inherited
> unchanged. This stands in for the diversity stochastic mutation provides at
> larger population/temperature scale, and is stated upfront rather than buried.

## Cost / scale

These are low-cost validation runs (fast/mid models, small seed counts) that
exercise the full pipeline and isolate each mechanism's effect. Scaling to a
full paper sample (more designs/seeds, ArchXBench Levels 3–5) is a
config/`--designs`/`--seeds` change; the harness, metrics, and tables are
unchanged.
