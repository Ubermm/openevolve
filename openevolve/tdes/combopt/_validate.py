"""Offline pipeline validation (no LLM). Run:

    python -m openevolve.tdes.combopt._validate mis
    python -m openevolve.tdes.combopt._validate maxcut

Checks, for the chosen problem:
  1. seed (weak) portfolio fails most tests;
  2. the strong reference portfolio passes units/integration;
  3. how warm-start (baseline vs strong) compares to cold CP-SAT (system gate);
  4. exact feasibility holds for every produced solution.
"""

from __future__ import annotations

import sys

from openevolve.tdes.combopt import benchmark_loader, exact, heuristic_runner
from openevolve.tdes.combopt.problems import Instance, get_problem
from openevolve.tdes.types import Candidate, TestLevel

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def _portfolio(source_map):
    return Candidate(modules=dict(source_map), generation=0)


def main(name: str) -> int:
    seed, suite, mutator = benchmark_loader.load_problem(name, with_mutator=True)
    problem = get_problem(name)
    classes = list(suite.module_names)
    strong = benchmark_loader.REFERENCE_SOURCES[name]

    n_unit = sum(1 for t in suite.tests if t.level == TestLevel.UNIT)
    n_int = sum(1 for t in suite.tests if t.level == TestLevel.INTEGRATION)
    n_sys = sum(1 for t in suite.tests if t.level == TestLevel.SYSTEM)
    print(f"== {name}: {n_unit} unit + {n_int} integration + {n_sys} system tests ==")

    # 1) seed (in-process, sandbox off for speed)
    seed_vec = suite.run(seed, sandbox=False)
    print(f"seed (weak)     : {seed_vec.summary()}")

    # 2) strong reference portfolio
    strong_cand = _portfolio({cls: strong for cls in classes})
    strong_vec = suite.run(strong_cand, sandbox=False)
    print(f"strong portfolio: {strong_vec.summary()}")

    # 3) system gate detail: cold vs baseline-warm vs strong-warm
    sys_test = next(t for t in suite.tests if t.level == TestLevel.SYSTEM)
    insts = [Instance.from_json(j) for j in sys_test.payload["instances"]]
    budget = sys_test.payload["budget_s"]
    cold = sys_test.payload["cold_objective_total"]

    base_fn, _ = heuristic_runner._compile_priority(problem.baseline_priority_source)
    strong_fn, _ = heuristic_runner._compile_priority(strong)

    def warm_total(fn):
        tot = 0.0
        for inst in insts:
            res = problem.run(fn, inst)
            assert res.feasible, f"infeasible: {res.error}"
            hint = exact.mis_hint_from_set(inst.n, res.solution) if name == "mis" else res.solution
            warm = exact.solve(name, inst, budget, hint=hint, deterministic=True).objective
            tot += max(res.quality, warm)  # hybrid: keep the better of heuristic and solver
        return tot

    base_warm = warm_total(base_fn)
    strong_warm = warm_total(strong_fn)
    print(f"\nsystem gate (budget={budget} det, {len(insts)} instances):")
    print(f"  cold CP-SAT        : {cold:g}")
    print(
        f"  baseline warm-start: {base_warm:g}  ({'beats' if base_warm > cold else 'ties/loses'})"
    )
    print(
        f"  strong   warm-start: {strong_warm:g}  ({'beats' if strong_warm > cold else 'ties/loses'})"
    )

    # 4) per-class strong vs baseline improvement
    print("\nper-class strong-vs-baseline quality (mean over unit instances):")
    for cls in classes:
        units = [t for t in suite.tests if t.level == TestLevel.UNIT and t.module == cls]
        b = sum(t.payload["baseline_quality"] for t in units) / len(units)
        s = 0.0
        for t in units:
            inst = Instance.from_json(t.payload["instance"])
            s += problem.run(strong_fn, inst).quality
        s /= len(units)
        print(f"  {cls:10s}: baseline {b:6.2f}  strong {s:6.2f}  {'+' if s >= b else '-'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "mis"))
