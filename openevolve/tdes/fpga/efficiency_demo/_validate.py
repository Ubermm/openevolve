"""
Deterministic validation of the efficiency demo's mechanism — no LLM, no API key.

Mirrors the role of ``combopt/_validate.py`` §1: prove the harness is sound
*before* any LLM runs.  Loads the three reference designs and shows that, under
the EfficiencySuite:

  * the seed (4 multipliers) is provably equivalent but fails the area budget,
  * the Gauss/Karatsuba rewrite (3 multipliers) is provably equivalent AND meets
    the budget — i.e. it SOLVES the suite (the discovery target), and
  * a smaller-but-wrong rewrite (3 multipliers, sign bug) is REJECTED by the
    formal gate, so it never earns the area pass — the gate is what makes
    efficiency-driven evolution safe.

    OSS_CAD_SUITE_ROOT=... python -m openevolve.tdes.fpga.efficiency_demo._validate
"""

from __future__ import annotations

import os
import sys

from openevolve.tdes.fpga import synthesis
from openevolve.tdes.fpga.efficiency_demo.efficiency_suite import EfficiencySuite
from openevolve.tdes.types import Candidate

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

_DESIGNS = os.path.join(os.path.dirname(__file__), "designs")


def _read(name: str) -> str:
    with open(os.path.join(_DESIGNS, f"{name}.v"), encoding="utf-8") as f:
        return f.read()


def main() -> int:
    golden = _read("golden")
    suite = EfficiencySuite(module="cmul", golden_source=golden, top="cmul", mul_budget=3)

    print("Efficiency demo — equivalence-gated multiplier minimization (cmul, complex multiply)\n")
    print(f"{'design':12s} {'$mul':>5s} {'equiv':>6s} {'area':>6s}  {'score_key':>12s}  verdict")
    print("-" * 70)
    expectations = {
        "seed": "correct, 4 mults — fails area budget (the start)",
        "karatsuba": "correct, 3 mults — SOLVES (the discovery target)",
        "broken": "3 mults but WRONG — formal gate rejects it",
    }
    ok = True
    for name in ("seed", "karatsuba", "broken"):
        src = _read(name)
        cand = Candidate(modules={"cmul": src})
        vec = suite.run(cand, timeout=180)
        rtl = synthesis.rtl_cell_counts({"cmul": src}, top_module="cmul")
        muls = synthesis.multiplier_count(rtl)
        equiv_pass = vec.results["unit:equiv"].passed
        area_pass = vec.results["system:area-mul<=3"].passed
        solved = vec.total_passes == len(suite.tests)
        print(
            f"{name:12s} {muls:>5d} {str(equiv_pass):>6s} {str(area_pass):>6s}  "
            f"{str(vec.score_key):>12s}  {expectations[name]}"
        )
        # Assertions encoding the intended behaviour.
        if name == "seed":
            ok &= equiv_pass and not area_pass
        elif name == "karatsuba":
            ok &= equiv_pass and area_pass and solved
        elif name == "broken":
            ok &= (not equiv_pass) and (not area_pass)

    print("-" * 70)
    print(
        "\nKey result: the Karatsuba rewrite removes one multiplier (4→3) and is "
        "PROVEN identical to the\nreference, so it solves the suite; the wrong "
        "rewrite is equally small but the formal gate blocks it.\n"
        "Lexicographic (system, integration, unit): karatsuba (1,0,1) > seed "
        "(0,0,1) > broken (0,0,0)."
    )
    print("\nVALIDATION:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
