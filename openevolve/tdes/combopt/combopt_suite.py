"""
CombOptTestSuite — a drop-in replacement for ``TDESTestSuite`` that evaluates a
candidate *heuristic portfolio* (one priority function per instance class) rather
than importing a Python codebase or simulating Verilog.

It produces the same :class:`~openevolve.tdes.types.TestVector` /
:class:`~openevolve.tdes.types.TestResult` / :class:`~openevolve.tdes.types.FeedbackTuple`
objects the unmodified controller/selection/crossover consume, exposing exactly
the four members those touch:

    * ``run(candidate, sandbox=, timeout=) -> TestVector``
    * ``tests``            (list, used via ``len(...)``)
    * ``module_names``     (the instance-class names, read by the CLI)
    * ``modules_for_tests(ids) -> list[str]``

Each test's *baselines* (classical-heuristic quality, cold CP-SAT objective) are
precomputed once at suite-construction time and inlined into the test spec, so
per-candidate evaluation only runs the (cheap) greedy harness plus, for the one
SYSTEM test, the warm-started solver. The harness recomputes every objective
exactly and verifies feasibility — the suite never trusts heuristic output.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence

from openevolve.tdes.combopt import heuristic_runner
from openevolve.tdes.types import (
    Candidate,
    FeedbackTuple,
    TestLevel,
    TestResult,
    TestVector,
)

logger = logging.getLogger(__name__)


@dataclass
class CombOptTest:
    """One hierarchical heuristic test (analog of ``VerilogTest``)."""

    id: str
    level: TestLevel
    module: str  # class this test is primarily attributed to (mutation routing)
    description: str  # natural-language; shown to the LLM
    kind: str  # "unit" | "integration" | "system"
    payload: Dict = field(default_factory=dict)  # precomputed baselines + instances
    modules: Optional[List[str]] = None  # all classes touched; defaults to [module]

    def touched_modules(self) -> List[str]:
        return list(self.modules) if self.modules else [self.module]

    def to_spec(self) -> dict:
        spec = {"id": self.id, "kind": self.kind, "module": self.module}
        spec.update(self.payload)
        return spec


class CombOptTestSuite:
    """A hierarchical suite over a fixed set of instance-class modules."""

    def __init__(
        self,
        problem: str,
        module_names: Sequence[str],
        tests: Sequence[CombOptTest],
    ):
        self.problem = problem
        self.module_names: List[str] = list(module_names)
        self.tests: List[CombOptTest] = list(tests)
        self.source_path: Optional[str] = None  # parity with TDESTestSuite (unused)

    # -- introspection (parity with TDESTestSuite) -----------------------
    def modules_for_tests(self, test_ids) -> List[str]:
        wanted = set(test_ids)
        out: List[str] = []
        for t in self.tests:
            if t.id in wanted:
                for m in t.touched_modules():
                    if m not in out:
                        out.append(m)
        return out

    def tests_for_module(self, module: str) -> List[CombOptTest]:
        return [t for t in self.tests if module in t.touched_modules()]

    # -- execution -------------------------------------------------------
    def run(self, candidate: Candidate, *, sandbox: bool = True, timeout: int = 120) -> TestVector:
        spec = {
            "problem": self.problem,
            "modules": dict(candidate.modules),
            "tests": [t.to_spec() for t in self.tests],
        }
        if sandbox:
            outcomes = heuristic_runner.run_in_subprocess(spec, timeout=timeout)
        else:
            outcomes = heuristic_runner.evaluate_spec(spec)

        vector = TestVector()
        for test in self.tests:
            o = outcomes.get(test.id, {"passed": False, "error": "no result", "failing_input": ""})
            feedback = None
            if not o["passed"]:
                feedback = FeedbackTuple(
                    description=test.description,
                    failing_input=o.get("failing_input", ""),
                    error=o.get("error", "unknown failure"),
                )
            vector.results[test.id] = TestResult(
                test_id=test.id,
                level=test.level,
                module=test.module,
                passed=o["passed"],
                description=test.description,
                feedback=feedback,
            )
        return vector
