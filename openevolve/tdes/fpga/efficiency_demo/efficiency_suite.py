"""
EfficiencySuite — the AlphaEvolve-TPU analog as a TDES drop-in suite.

The task: start from a **correct** arithmetic circuit and evolve a
*functionally-identical* rewrite that uses fewer (expensive) multipliers — the
"removed unnecessary arithmetic in a matmul circuit, must pass robust
verification" result, in miniature.  The demo circuit is a complex multiplier;
the discovery is the 4→3 multiplier Gauss/Karatsuba identity.

Hierarchy (the lexicographic ``TestVector`` levels):

  * **UNIT  ``equiv``** — the candidate is *formally* equivalent to the golden
    reference (Yosys miter + SAT, ``equivalence.py``).  This is the invariant:
    every higher reward is gated on it.
  * **SYSTEM ``area``** — the candidate is equivalent **and** its multiplier
    count is at or below the budget.  Gating area on equivalence is essential:
    without it a smaller-but-wrong design (3 multipliers, sign bug) would score
    a SYSTEM pass and, under the (system, integration, unit) key, *outrank* the
    correct seed.  "Smaller" only earns credit when "correct" already holds —
    exactly AlphaEvolve's verification-gated efficiency.

Duck-typed against the controller: exposes ``run``, ``tests``, ``module_names``,
``modules_for_tests`` (same four members ``VerilogTestSuite`` exposes).  Base
``tdes/*`` is untouched.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence

from openevolve.tdes.fpga import equivalence, synthesis
from openevolve.tdes.types import (
    Candidate,
    FeedbackTuple,
    TestLevel,
    TestResult,
    TestVector,
)

logger = logging.getLogger(__name__)


@dataclass
class EfficiencyTest:
    id: str
    level: TestLevel
    module: str
    description: str

    def touched_modules(self) -> List[str]:
        return [self.module]


class EfficiencySuite:
    """Equivalence-gated area-minimization suite over one combinational module."""

    def __init__(
        self,
        *,
        module: str,
        golden_source: str,
        top: Optional[str] = None,
        mul_budget: int = 3,
        timeout: int = 180,
    ):
        self.module = module
        self.golden_source = golden_source
        self.top = top or module
        self.mul_budget = mul_budget
        self.timeout = timeout
        self.module_names: List[str] = [module]
        self.source_path: Optional[str] = None  # parity with TDESTestSuite (unused)
        self.tests: List[EfficiencyTest] = [
            EfficiencyTest(
                id="unit:equiv",
                level=TestLevel.UNIT,
                module=module,
                description=(
                    f"The '{module}' module must be FUNCTIONALLY IDENTICAL to the "
                    "reference for every input (proven by formal equivalence "
                    "checking, not just simulation). Preserve exact behaviour."
                ),
            ),
            EfficiencyTest(
                id=f"system:area-mul<={mul_budget}",
                level=TestLevel.SYSTEM,
                module=module,
                description=(
                    f"While remaining provably equivalent, the '{module}' module "
                    f"must use at most {mul_budget} multipliers (fewer multiplier "
                    "instances = less area/power). Restructure the arithmetic to "
                    "remove a multiplication without changing the result."
                ),
            ),
        ]

    # -- introspection (controller / crossover contract) -----------------
    def modules_for_tests(self, test_ids) -> List[str]:
        wanted = set(test_ids)
        return [self.module] if any(t.id in wanted for t in self.tests) else []

    # -- execution -------------------------------------------------------
    def run(self, candidate: Candidate, *, sandbox: bool = True, timeout: int = 60) -> TestVector:
        cand_src = candidate.modules.get(self.module, "")
        t = max(timeout, self.timeout)

        # One formal-equivalence proof and one RTL multiplier count drive both
        # tests (computed once, reused).
        equiv = equivalence.check_equivalence(cand_src, self.golden_source, top=self.top, timeout=t)
        rtl = synthesis.rtl_cell_counts(candidate.modules, top_module=self.top, timeout=t)
        muls = synthesis.multiplier_count(rtl) if rtl.ok else None

        vector = TestVector()

        # UNIT: formal equivalence -------------------------------------------------
        if not equiv.ok:
            equiv_pass, equiv_err, equiv_in = False, equiv.error or "equivalence check failed", ""
        elif equiv.equivalent:
            equiv_pass, equiv_err, equiv_in = True, "", ""
        else:
            equiv_pass = False
            equiv_err = "candidate is NOT equivalent to the reference (counterexample found)"
            equiv_in = (equiv.counterexample or "").splitlines()[0:1]
            equiv_in = equiv_in[0] if equiv_in else "see counterexample"
        vector.results["unit:equiv"] = self._result(
            "unit:equiv", TestLevel.UNIT, equiv_pass, equiv_in, equiv_err
        )

        # SYSTEM: area, gated on equivalence ---------------------------------------
        area_id = f"system:area-mul<={self.mul_budget}"
        if not equiv_pass:
            area_pass = False
            area_err = "area is not scored until the design is provably equivalent"
            area_in = ""
        elif muls is None:
            area_pass = False
            area_err = f"could not synthesize to count multipliers: {rtl.error}"
            area_in = ""
        elif muls <= self.mul_budget:
            area_pass, area_err, area_in = True, "", ""
        else:
            area_pass = False
            area_err = f"uses {muls} multipliers, budget is {self.mul_budget}"
            area_in = f"{muls} multipliers"
        vector.results[area_id] = self._result(
            area_id, TestLevel.SYSTEM, area_pass, area_in, area_err
        )
        return vector

    def _result(self, tid, level, passed, failing_input, error) -> TestResult:
        desc = next(t.description for t in self.tests if t.id == tid)
        feedback = None
        if not passed:
            feedback = FeedbackTuple(description=desc, failing_input=failing_input, error=error)
        return TestResult(
            test_id=tid,
            level=level,
            module=self.module,
            passed=passed,
            description=desc,
            feedback=feedback,
        )
