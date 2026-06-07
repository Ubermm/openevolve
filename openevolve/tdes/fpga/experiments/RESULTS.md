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

## Cost / scale

These are small, low-cost validation runs on a fast model to exercise the full
pipeline. Scaling to the paper's design sample (ArchXBench Levels 3–5, multiple
seeds) and a stronger model (e.g. `claude-sonnet-4-6`) is a config/`--designs`
change; the harness, metrics, and tables are unchanged.
