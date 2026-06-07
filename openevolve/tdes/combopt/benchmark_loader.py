"""
Build a ``(seed, CombOptTestSuite, reference_mutator)`` triple for a combinatorial
problem, with every baseline / cold-solver value precomputed and inlined.

Layout of a built suite (with the default 3 classes):

  * **UNIT** (one per class instance): the class-``c`` priority module must match
    or beat the *classical baseline heuristic* on a class-``c`` instance.
  * **INTEGRATION** (one per class, all touching every module): the routed
    portfolio must match or beat the baseline in aggregate over a mixed
    validation batch — i.e. every class must be competent at once.
  * **SYSTEM** (one): the portfolio's solutions, used as warm-start hints, must
    make CP-SAT strictly beat its own cold objective under a fixed deterministic
    budget (the "heuristic + exact solver beats exact alone" gate).

The **seed** is a deliberately weak portfolio (constant priority) so evolution has
real work to do. The **reference mutator** injects a strong, class-agnostic
*adaptive* heuristic for whichever module is being repaired — enabling fully
offline validation, ablations, and the crossover demo without an API key
(mirrors the scripted reference mutator in the FPGA layer).
"""

from __future__ import annotations

from typing import List, Optional, Tuple

from openevolve.tdes.combopt import exact, heuristic_runner
from openevolve.tdes.combopt.combopt_suite import CombOptTest, CombOptTestSuite
from openevolve.tdes.combopt.problems import CLASSES, Instance, get_problem
from openevolve.tdes.mutation import ScriptedMutator
from openevolve.tdes.types import Candidate, TestLevel

# Deliberately weak starting heuristic: constant priority (no class knowledge).
WEAK_SEED_SOURCE = "def priority(v, graph):\n    return 0.0\n"

# Strong reference heuristics used by the offline scripted mutator. Both use the
# harness-maintained residual state, so they are genuine *adaptive* greedies that
# match-or-beat the static classical baselines.
REFERENCE_SOURCES = {
    "mis": (
        "def priority(v, graph):\n"
        "    # Adaptive minimum residual-degree greedy (beats static min-degree).\n"
        "    avail = graph.state.get('available')\n"
        "    if avail is None:\n"
        "        return -float(graph.degree(v))\n"
        "    res_deg = sum(1 for u in graph.neighbors(v) if u in avail)\n"
        "    return -float(res_deg)\n"
    ),
    "maxcut": (
        "def priority(v, graph):\n"
        "    # Steepest-ascent move selection: take the largest-gain improving flip.\n"
        "    return graph.state['gain'][v]\n"
    ),
}

# Per-problem SYSTEM-test instance regimes, hand-tuned so the *cold* CP-SAT
# solver is competent (not a strawman) yet only a strong portfolio's hybrid beats
# it under the budget, while the weak seed does not (verified empirically). Each
# entry: (class, n, count).
SYSTEM_SPECS = {
    "mis": {"budget": 0.08, "instances": [("sparse", 300, 2), ("clustered", 200, 2)]},
    "maxcut": {"budget": 0.08, "instances": [("sparse", 300, 3)]},
}


def _baseline_quality(problem, inst: Instance) -> float:
    fn, err = heuristic_runner._compile_priority(problem.baseline_priority_source)
    if fn is None:  # pragma: no cover - baseline is authored here, always valid
        raise RuntimeError(f"baseline failed to compile: {err}")
    res = problem.run(fn, inst)
    if not res.feasible:  # pragma: no cover
        raise RuntimeError(f"baseline infeasible on {inst.id}: {res.error}")
    return res.quality


def load_problem(
    name: str,
    *,
    with_mutator: bool = True,
    unit_per_class: int = 3,
    unit_n: int = 60,
    val_per_class: int = 2,
    val_n: int = 60,
    include_system: bool = True,
    base_seed: int = 1000,
) -> Tuple[Candidate, CombOptTestSuite, Optional[ScriptedMutator]]:
    problem = get_problem(name)
    sys_spec = SYSTEM_SPECS[name]
    system_budget = sys_spec["budget"]

    # --- instances -------------------------------------------------------
    unit_instances = {
        cls: problem.make_instances(cls, unit_per_class, base_seed=base_seed + 100 * i, n=unit_n)
        for i, cls in enumerate(CLASSES)
    }
    val_by_class = {
        cls: problem.make_instances(
            cls, val_per_class, base_seed=base_seed + 5000 + 100 * i, n=val_n
        )
        for i, cls in enumerate(CLASSES)
    }
    system_instances: List[Instance] = []
    for j, (cls, n, count) in enumerate(sys_spec["instances"]):
        system_instances += problem.make_instances(
            cls, count, base_seed=base_seed + 9000 + 137 * j, n=n
        )

    tests: List[CombOptTest] = []

    # --- UNIT ------------------------------------------------------------
    for cls in CLASSES:
        for inst in unit_instances[cls]:
            bq = _baseline_quality(problem, inst)
            tests.append(
                CombOptTest(
                    id=f"unit:{inst.id}",
                    level=TestLevel.UNIT,
                    module=cls,
                    description=(
                        f"The '{cls}' heuristic must match or beat the classical "
                        f"baseline ({problem.name}) on a {cls} graph of {inst.n} nodes."
                    ),
                    kind="unit",
                    payload={"instance": inst.to_json(), "baseline_quality": bq},
                    modules=[cls],
                )
            )

    # --- INTEGRATION (per class: held-out batch generalization) ----------
    # Each class's heuristic must match or beat the classical baseline in
    # AGGREGATE over a held-out validation batch of that class (a robustness /
    # generalization check beyond the single-instance unit tests). Per-class (not
    # mixed) so a portfolio strong on only some classes fails the rest — which is
    # what makes complementary-coverage crossover necessary under a tight budget.
    for cls in CLASSES:
        batch = val_by_class[cls]
        base_total = sum(_baseline_quality(problem, inst) for inst in batch)
        tests.append(
            CombOptTest(
                id=f"integration:{cls}",
                level=TestLevel.INTEGRATION,
                module=cls,
                description=(
                    f"The '{cls}' heuristic must match or beat the classical baseline in "
                    f"aggregate over a held-out batch of {cls} instances (generalization)."
                ),
                kind="integration",
                payload={"instances": [i.to_json() for i in batch], "baseline_total": base_total},
                modules=[cls],
            )
        )

    # --- SYSTEM (warm-start vs cold solver under budget) -----------------
    # Omitted for the crossover-necessity ablation: the SYSTEM test is the
    # lexicographic top level, so an early partial portfolio that happens to pass
    # it is promoted and suppresses the complementary unit-level diversity that
    # crossover combines. With units+integration only, ranking tracks per-class
    # coverage and crossover grafts cleanly (the hybrid result is measured
    # separately). include_system=True keeps the full hierarchy for method runs.
    if include_system:
        cold_total = 0.0
        for inst in system_instances:
            cold_total += exact.solve(
                name, inst, system_budget, hint=None, deterministic=True
            ).objective
        tests.append(
            CombOptTest(
                id="system:warmstart",
                level=TestLevel.SYSTEM,
                module=CLASSES[0],
                description=(
                    "Used as warm-start hints, the portfolio's solutions must make "
                    "CP-SAT strictly beat its cold objective under a fixed budget."
                ),
                kind="system",
                payload={
                    "instances": [inst.to_json() for inst in system_instances],
                    "budget_s": system_budget,
                    "cold_objective_total": cold_total,
                },
                modules=list(CLASSES),
            )
        )

    suite = CombOptTestSuite(problem=name, module_names=list(CLASSES), tests=tests)
    seed = Candidate(
        modules={cls: WEAK_SEED_SOURCE for cls in CLASSES},
        generation=0,
        metadata={"origin": "seed", "problem": name},
    )

    mutator = None
    if with_mutator:
        strong = REFERENCE_SOURCES[name]

        def _fix(module, source, feedback, memory_text):
            if source.strip() == strong.strip():
                return None
            return strong, f"inject adaptive reference heuristic for '{module}'"

        mutator = ScriptedMutator(_fix)

    return seed, suite, mutator
