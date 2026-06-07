"""
Sandboxed evaluation of an evolved heuristic *portfolio* against a spec of
hierarchical tests.

A *spec* (plain JSON) is self-contained: it carries the problem name, the
candidate's per-class priority-function sources, and a list of tests with all
precomputed baselines/cold-solver values inlined. ``evaluate_spec`` runs every
test and returns ``{test_id: {passed, error, failing_input}}``. It is importable
(so the suite can run it in-process for offline tests) and is also the entry
point of the ``__main__`` driver used for subprocess isolation when evaluating
real LLM-written code.

Test kinds (mapping onto the TDES hierarchy):

  * ``unit``        (UNIT)        — the class-``c`` priority module beats the
    classical baseline on one class-``c`` instance (quality ≥ baseline_quality).
  * ``integration`` (INTEGRATION) — the routed *portfolio* beats the baseline in
    aggregate over a mixed validation batch (needs every class competent).
  * ``system``      (SYSTEM)      — the portfolio's solutions, used as a
    **warm-start hint**, make CP-SAT beat its own cold (no-hint) objective under
    a fixed deterministic budget. This is the headline "heuristic + exact solver
    beats exact solver alone" gate.

Feasibility is always recomputed exactly by ``problems.Problem.verify`` — a
heuristic that emits an infeasible structure fails with a concrete CEGIS error.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from typing import Dict, List, Optional, Tuple

from openevolve.tdes.combopt.problems import Instance, get_problem

# ---------------------------------------------------------------------------
# Priority-function compilation (the only place candidate code is exec'd)
# ---------------------------------------------------------------------------


def _compile_priority(source: str):
    """Exec a module source and return (priority_fn | None, error_str)."""
    ns: Dict[str, object] = {}
    try:
        compiled = compile(source, "<priority>", "exec")
        exec(compiled, ns)  # noqa: S102 - sandboxed by subprocess in real runs
    except Exception as e:  # noqa: BLE001
        return None, f"module failed to load: {type(e).__name__}: {e}"
    fn = ns.get("priority")
    if not callable(fn):
        return None, "module does not define a callable `priority(v, graph)`"
    return fn, ""


# ---------------------------------------------------------------------------
# Per-test evaluation
# ---------------------------------------------------------------------------


def _fail(error: str, failing_input: str = "") -> dict:
    return {"passed": False, "error": error, "failing_input": failing_input}


def _ok() -> dict:
    return {"passed": True, "error": "", "failing_input": ""}


def _portfolio_solution(
    problem, fns, errs, inst: Instance
) -> Tuple[Optional[List[int]], float, str]:
    """Route an instance to its class module and run the harness. Returns
    (solution|None, quality, error)."""
    fn = fns.get(inst.cls)
    if fn is None:
        return None, 0.0, errs.get(inst.cls, f"no module for class '{inst.cls}'")
    res = problem.run(fn, inst)
    if not res.feasible:
        return None, 0.0, res.error
    return res.solution, res.quality, ""


def _eval_unit(problem, fns, errs, t: dict) -> dict:
    inst = Instance.from_json(t["instance"])
    sol, quality, err = _portfolio_solution(problem, fns, errs, inst)
    if sol is None:
        return _fail(err, inst.id)
    if quality + 1e-9 >= t["baseline_quality"]:
        return _ok()
    return _fail(
        f"quality {quality:g} < baseline {t['baseline_quality']:g} on {inst.cls} instance",
        f"{inst.id} (n={inst.n}, {len(inst.edges)} edges)",
    )


def _eval_integration(problem, fns, errs, t: dict) -> dict:
    total = 0.0
    worst = None
    for ij in t["instances"]:
        inst = Instance.from_json(ij)
        sol, quality, err = _portfolio_solution(problem, fns, errs, inst)
        if sol is None:
            return _fail(err, inst.id)
        total += quality
        if worst is None or quality < worst[1]:
            worst = (inst.cls, quality)
    if total + 1e-9 >= t["baseline_total"]:
        return _ok()
    return _fail(
        f"portfolio total {total:g} < baseline total {t['baseline_total']:g} "
        f"(weakest class so far: {worst[0] if worst else '?'})",
        f"validation batch of {len(t['instances'])} instances",
    )


def _eval_system(problem, fns, errs, t: dict) -> dict:
    """Hybrid pipeline vs the exact solver alone, under the same budget.

    The hybrid keeps, per instance, the best of (a) the evolved heuristic's
    feasible solution and (b) the warm-started solver's incumbent — exactly what
    a practitioner does with a feasible hint (never do worse than the hint). On
    hard instances the budgeted solver's incumbent is poor while the greedy is
    strong, so the hybrid strictly beats the cold solver. The gate is honest:
    both sides get the identical deterministic budget.
    """
    from openevolve.tdes.combopt import exact

    hybrid_total = 0.0
    for ij in t["instances"]:
        inst = Instance.from_json(ij)
        sol, greedy_q, err = _portfolio_solution(problem, fns, errs, inst)
        if sol is None:
            return _fail(f"portfolio could not solve a system instance: {err}", inst.id)
        if problem.name == "mis":
            hint = exact.mis_hint_from_set(inst.n, sol)
        else:
            hint = sol
        warm = exact.solve(problem.name, inst, t["budget_s"], hint=hint, deterministic=True)
        hybrid_total += max(greedy_q, warm.objective)
    cold_total = t["cold_objective_total"]
    if hybrid_total > cold_total + 1e-9:
        return _ok()
    return _fail(
        f"hybrid total {hybrid_total:g} did not beat cold CP-SAT total "
        f"{cold_total:g} under the same deterministic budget {t['budget_s']}",
        f"{len(t['instances'])} system instances",
    )


_EVALUATORS = {"unit": _eval_unit, "integration": _eval_integration, "system": _eval_system}


def evaluate_spec(spec: dict) -> Dict[str, dict]:
    """Evaluate every test in ``spec``; returns {test_id: outcome dict}."""
    problem = get_problem(spec["problem"])
    fns: Dict[str, object] = {}
    errs: Dict[str, str] = {}
    for cls, src in spec["modules"].items():
        fn, err = _compile_priority(src)
        fns[cls] = fn
        if err:
            errs[cls] = err
    out: Dict[str, dict] = {}
    for t in spec["tests"]:
        evaluator = _EVALUATORS[t["kind"]]
        try:
            out[t["id"]] = evaluator(problem, fns, errs, t)
        except Exception as e:  # noqa: BLE001 - a harness bug must not crash the sweep
            out[t["id"]] = _fail(f"evaluation raised: {type(e).__name__}: {e}")
    return out


# ---------------------------------------------------------------------------
# Subprocess isolation (used when evaluating real LLM code)
# ---------------------------------------------------------------------------


def _kill_tree(proc: subprocess.Popen) -> None:
    try:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                capture_output=True,
                check=False,
            )
        else:
            proc.kill()
    except Exception:  # noqa: BLE001
        pass


def run_in_subprocess(spec: dict, timeout: int) -> Dict[str, dict]:
    """Run ``evaluate_spec`` in a fresh Python process with a hard timeout.

    On timeout, the whole process tree is killed and every test is marked failed
    with a timeout error (so a runaway heuristic costs one generation, not the run).
    """
    with tempfile.TemporaryDirectory(prefix="combopt_") as td:
        spec_path = os.path.join(td, "spec.json")
        out_path = os.path.join(td, "out.json")
        with open(spec_path, "w", encoding="utf-8") as f:
            json.dump(spec, f)
        proc = subprocess.Popen(
            [sys.executable, "-m", "openevolve.tdes.combopt.heuristic_runner", spec_path, out_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        try:
            _out, errb = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            _kill_tree(proc)
            proc.communicate()
            return {
                t["id"]: _fail(f"evaluation exceeded {timeout}s budget", "timeout")
                for t in spec["tests"]
            }
        if not os.path.exists(out_path):
            err = errb.decode("utf-8", "replace")[-500:] if errb else "no output produced"
            return {t["id"]: _fail(f"subprocess crashed: {err}") for t in spec["tests"]}
        with open(out_path, "r", encoding="utf-8") as f:
            return json.load(f)


def _main(argv: List[str]) -> int:
    spec_path, out_path = argv[1], argv[2]
    with open(spec_path, "r", encoding="utf-8") as f:
        spec = json.load(f)
    results = evaluate_spec(spec)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f)
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv))
