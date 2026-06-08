# TDES-FPGA efficiency demo (the AlphaEvolve-TPU analog)

Evolve a **correct** arithmetic circuit into a **provably-equivalent, smaller**
one — AlphaEvolve's TPU Verilog rewrite ("removed unnecessary arithmetic in a
matmul circuit; must pass robust verification"), in miniature.

The design is a complex multiplier; the discovery is the **4 → 3 multiplier**
Gauss/Karatsuba identity. Unlike the rest of the FPGA layer (which verifies by
*simulation* and evolves toward *correctness*), this demo:

1. starts from an already-correct design (`designs/seed.v`),
2. verifies with **formal equivalence** (Yosys miter + SAT, `equivalence.py`) —
   so an efficiency rewrite is accepted only if it is correct for *every* input,
3. optimizes **area** (the RTL `$mul` count, `synthesis.py::rtl_cell_counts`).

`efficiency_suite.py` is a TDES drop-in suite (duck-typed against the base
controller — `run` / `tests` / `module_names` / `modules_for_tests`; base
`tdes/*` untouched). Its hierarchy makes equivalence the invariant and
area-under-budget the goal, with area **gated on equivalence** so a
smaller-but-wrong design can never outrank a correct one.

## Run

```bash
export OSS_CAD_SUITE_ROOT=/path/to/oss-cad-suite

# deterministic mechanism proof (no API key)
python -m openevolve.tdes.fpga.efficiency_demo._validate

# real LLM: discover the 3-multiplier design from the 4-multiplier seed
ANTHROPIC_API_KEY=... python -m openevolve.tdes.fpga.efficiency_demo.run_demo \
    --config openevolve/tdes/fpga/experiments/configs/anthropic_sonnet.yaml

# tests (gated on yosys)
python -m unittest openevolve.tdes.fpga.tests.test_efficiency_demo
```

See `RESULTS.md` for the measured run (Sonnet found the Gauss algorithm in 2
generations, SAT-verified). `designs/` holds the seed, golden reference, the
Karatsuba target, the `broken` cheat (for the gate-rejection test), and
`evolved_gauss.v` (the LLM's actual discovery).
