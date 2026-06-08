# Efficiency demo: the AlphaEvolve-TPU rewrite, in miniature

This is the **A** demo (the TPU analog of AlphaEvolve's Verilog result): start
from a *correct* arithmetic circuit and evolve a **functionally-identical**
rewrite that uses fewer multipliers, where the efficiency win is only accepted
if it passes **formal verification** — not simulation.

> "AlphaEvolve proposed a Verilog rewrite that removed unnecessary bits in a
> key, highly optimized arithmetic circuit for matrix multiplication. Crucially,
> the proposal must pass robust verification methods to confirm that the
> modified circuit maintains functional correctness."

We reproduce that loop on a complex multiplier (the smallest faithful instance
of "arithmetic in a matmul circuit"). The known result is that a complex
multiply needs only **3 real multiplications, not 4** (Gauss / Karatsuba) — a
direct "remove unnecessary arithmetic" target.

## What TDES evolves

* **Seed** (`designs/seed.v`): the obvious, correct 4-multiplier complex
  multiply — `ar*br, ai*bi, ar*bi, ai*br`.
* **Golden** (`designs/golden.v`): the functional spec; the equivalence oracle.
* **Gate** (`equivalence.py`): Yosys **miter + SAT** proves the candidate is
  combinationally identical to the golden for *every* input.
* **Fitness** (`synthesis.py::rtl_cell_counts`): the number of `$mul` cells at
  RTL (before technology mapping), the area signal full `synth` would hide.

Hierarchy (`efficiency_suite.py`): **UNIT `equiv`** (formally equivalent — the
invariant) → **SYSTEM `area-mul<=3`** (equivalent *and* ≤ 3 multipliers). Area
is gated on equivalence, so "smaller" never outranks "correct".

## 1. Mechanism — deterministic, no LLM (`_validate.py`)

| design | `$mul` | formally equivalent | area pass | score_key | meaning |
|---|---|---|---|---|---|
| seed       | 4 | ✓ | ✗ | (0,0,1) | correct, over budget (start) |
| karatsuba  | 3 | ✓ | ✓ | (1,0,1) | correct & small — **solves** |
| broken     | 3 | ✗ | ✗ | (0,0,0) | small but WRONG — gate rejects |

`broken` (`designs/broken.v`) has only 3 multipliers but a sign bug; the formal
gate finds a counterexample and refuses it. Under the lexicographic key
`karatsuba (1,0,1) > seed (0,0,1) > broken (0,0,0)` — i.e. an incorrect-but-small
design is correctly ranked *below* the correct seed. The gate is what makes
area-driven evolution safe.

## 2. Discovery — real LLM (Claude Sonnet 4.6, `run_demo.py`)

From the 4-multiplier seed, with only the feedback *"uses 4 multipliers, budget
is 3; restructure the arithmetic to remove a multiplication without changing the
result"*, TDES reached a **SAT-proven-equivalent 3-multiplier design in 2
generations**:

```
seed multipliers:  4
best multipliers:  3
formally equivalent: True
SOLVED (equivalent AND under budget): True
generations: 2
```

The evolved design (`designs/evolved_gauss.v`) independently found the **Gauss
algorithm** — `m3 = (ar+ai)(br+bi); yi = m3 - m1 - m2` — a *different*, more
canonical 3-multiplier form than the Karatsuba reference we seeded, discovered
on its own and formally verified. This is the AlphaEvolve pattern end to end: an
LLM proposes a functionally-equivalent, cheaper arithmetic circuit, and a robust
(formal) verifier confirms correctness before it is accepted.

## Honesty notes

* The area metric is **`$mul` count at RTL** (pre-techmap). Multipliers are the
  expensive resource (DSP/LUT-heavy); trading one multiplier for two adders is a
  real win on FPGA/ASIC. Raw post-`synth` *generic* cell count actually rises
  (the 3-mult form adds two adders), which is exactly why the multiplier count,
  not gate count, is the right objective — and why a synthesis tool's own
  area pass does **not** make this substitution for you.
* This is a *single-design* demo of the capability (the headline NP-hard result
  is the CombOpt layer). It deliberately uses small 4-bit inputs so the SAT
  equivalence proof is instant; the flow scales to wider datapaths at the cost
  of SAT time, where bounded/inductive equivalence (`equiv_opt`) would replace
  the monolithic miter.

## Reproduce

```bash
export OSS_CAD_SUITE_ROOT=/path/to/oss-cad-suite
python -m openevolve.tdes.fpga.efficiency_demo._validate          # §1, deterministic
ANTHROPIC_API_KEY=... python -m openevolve.tdes.fpga.efficiency_demo.run_demo \
    --config openevolve/tdes/fpga/experiments/configs/anthropic_sonnet.yaml   # §2
```
