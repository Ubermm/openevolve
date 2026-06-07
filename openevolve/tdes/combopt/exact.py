"""
Downstream *exact* solvers (OR-Tools CP-SAT) for the combinatorial problems,
with optional **warm-start hints**.

This is the "static method" half of the AlphaEvolve-style hybrid: the LLM-evolved
heuristic constructs a feasible solution, and that solution is fed to CP-SAT as a
hint (``AddHint``) before solving under a wall-clock budget. Under a budget too
short for CP-SAT to prove optimality on its own, a better warm start yields a
better incumbent — the mechanism by which "evolved heuristic + exact solver"
can beat "exact solver alone".

Each solver returns a :class:`ExactResult` with the best objective found, whether
optimality was proven, and the wall-clock used. Everything here is deterministic
given the model + budget + worker count (we fix ``num_search_workers=1`` so the
warm-start comparison is controlled and reproducible).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

from ortools.sat.python import cp_model

from openevolve.tdes.combopt.problems import Instance


@dataclass
class ExactResult:
    objective: float
    optimal: bool
    wall_time: float
    status: str
    solution: List[int]


def _solve(
    model: cp_model.CpModel, budget_s: float, sense_vars, deterministic: bool
) -> ExactResult:
    solver = cp_model.CpSolver()
    if deterministic:
        # Deterministic time makes warm-vs-cold comparisons reproducible across
        # machines/load (termination by work units, not wall-clock).
        solver.parameters.max_deterministic_time = float(budget_s)
    else:
        solver.parameters.max_time_in_seconds = float(budget_s)
    solver.parameters.num_search_workers = 1  # controlled / reproducible
    solver.parameters.random_seed = 0
    status = solver.Solve(model)
    status_name = solver.StatusName(status)
    if status in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        sol = [int(solver.Value(x)) for x in sense_vars]
        return ExactResult(
            objective=solver.ObjectiveValue(),
            optimal=(status == cp_model.OPTIMAL),
            wall_time=solver.WallTime(),
            status=status_name,
            solution=sol,
        )
    return ExactResult(0.0, False, solver.WallTime(), status_name, [])


def solve_maxcut(
    inst: Instance, budget_s: float, hint: Optional[List[int]] = None, deterministic: bool = False
) -> ExactResult:
    model = cp_model.CpModel()
    x = [model.NewBoolVar(f"x{v}") for v in range(inst.n)]
    # y_e == 1 iff edge e is cut; maximize sum w_e * y_e.
    terms = []
    for i, (u, v, w) in enumerate(inst.edges):
        y = model.NewBoolVar(f"y{i}")
        # y <= x_u + x_v, y <= 2 - x_u - x_v, and y >= x_u - x_v, y >= x_v - x_u
        model.Add(y <= x[u] + x[v])
        model.Add(y <= 2 - x[u] - x[v])
        model.Add(y >= x[u] - x[v])
        model.Add(y >= x[v] - x[u])
        terms.append(int(w) * y)
    model.Maximize(sum(terms))
    if hint is not None:
        for v in range(inst.n):
            model.AddHint(x[v], int(hint[v]))
    return _solve(model, budget_s, x, deterministic)


def solve_mis(
    inst: Instance, budget_s: float, hint: Optional[List[int]] = None, deterministic: bool = False
) -> ExactResult:
    model = cp_model.CpModel()
    x = [model.NewBoolVar(f"x{v}") for v in range(inst.n)]
    for u, v, _ in inst.edges:
        model.Add(x[u] + x[v] <= 1)  # independence
    model.Maximize(sum(x))
    if hint is not None:
        chosen = set(hint)
        for v in range(inst.n):
            model.AddHint(x[v], 1 if v in chosen else 0)
    return _solve(model, budget_s, x, deterministic)


SOLVERS = {"maxcut": solve_maxcut, "mis": solve_mis}


def solve(
    problem_name: str, inst: Instance, budget_s: float, hint=None, deterministic: bool = False
) -> ExactResult:
    return SOLVERS[problem_name](inst, budget_s, hint, deterministic)


def mis_hint_from_set(n: int, chosen: List[int]) -> List[int]:
    """Convert an MIS vertex list to a 0/1 hint vector of length n."""
    s = set(chosen)
    return [1 if v in s else 0 for v in range(n)]
