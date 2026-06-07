"""
Non-evolutionary baselines for TDES-CombOpt comparison.

  * ``single_agent_repair`` — one candidate portfolio, iterate run-tests → send
    CEGIS failures to the LLM → fix each failing module → repeat for N rounds.
  * ``pass_at_k`` — generate k independent portfolios from scratch (each class
    heuristic generated fresh, no feedback), keep the best by the suite.

Both reuse the same ``LLMEnsemble`` and ``HeuristicLLMMutator`` plumbing as TDES,
so the comparison is apples-to-apples (same model, same harness, same feedback).
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from typing import List, Optional

from openevolve.tdes.combopt import prompts
from openevolve.tdes.combopt.combopt_suite import CombOptTestSuite
from openevolve.tdes.combopt.mutation import HeuristicLLMMutator
from openevolve.tdes.types import Candidate
from openevolve.utils.code_utils import parse_full_rewrite


@dataclass
class BaselineResult:
    solved: bool
    total_passes: int
    total_tests: int
    rounds_used: int
    best: Candidate
    trajectory: List[int] = field(default_factory=list)


def single_agent_repair(
    seed: Candidate,
    suite: CombOptTestSuite,
    ensemble,
    problem_name: str,
    *,
    rounds: int = 5,
    timeout: int = 120,
    sandbox: bool = True,
    diff_based: bool = False,
) -> BaselineResult:
    """Iterative single-candidate portfolio repair using CEGIS feedback."""
    return asyncio.run(
        _single_agent_async(
            seed, suite, ensemble, problem_name, rounds, timeout, sandbox, diff_based
        )
    )


async def _single_agent_async(
    seed, suite, ensemble, problem_name, rounds, timeout, sandbox, diff_based
) -> BaselineResult:
    mutator = HeuristicLLMMutator(ensemble, problem_name, diff_based=diff_based)
    current = seed.clone()
    current.vector = suite.run(current, sandbox=sandbox, timeout=timeout)
    trajectory = [current.vector.total_passes]
    total = len(suite.tests)

    for r in range(rounds):
        if current.vector.total_passes == total:
            break
        for module in current.vector.failing_modules():
            feedback = [
                res.feedback
                for res in current.vector.results.values()
                if not res.passed and res.module == module and res.feedback is not None
            ]
            proposal = await mutator.propose(
                candidate=current,
                module=module,
                feedback=feedback,
                memory_text="",  # single-agent baseline has no negative memory
                generation=r + 1,
            )
            if proposal is None:
                continue
            current.modules[module] = proposal.new_source
        current.vector = suite.run(current, sandbox=sandbox, timeout=timeout)
        trajectory.append(current.vector.total_passes)

    passes = current.vector.total_passes
    return BaselineResult(
        solved=passes == total and total > 0,
        total_passes=passes,
        total_tests=total,
        rounds_used=len(trajectory) - 1,
        best=current,
        trajectory=trajectory,
    )


def pass_at_k(
    seed: Candidate,
    suite: CombOptTestSuite,
    ensemble,
    problem_name: str,
    *,
    k: int = 5,
    timeout: int = 120,
    sandbox: bool = True,
) -> BaselineResult:
    """Generate k independent portfolios from scratch; keep the best by the suite."""
    return asyncio.run(_pass_at_k_async(seed, suite, ensemble, problem_name, k, timeout, sandbox))


async def _pass_at_k_async(
    seed, suite, ensemble, problem_name, k, timeout, sandbox
) -> BaselineResult:
    total = len(suite.tests)
    classes = list(suite.module_names)
    best: Optional[Candidate] = None
    best_passes = -1

    for _ in range(k):
        modules = {}
        for cls in classes:
            resp = await ensemble.generate_with_context(
                system_message=prompts.SYSTEM_MESSAGE_COMBOPT,
                messages=[
                    {"role": "user", "content": prompts.build_generation_prompt(problem_name, cls)}
                ],
            )
            code = parse_full_rewrite(resp or "", "python")
            modules[cls] = code if (code and code.strip()) else seed.modules[cls]
        cand = Candidate(modules=modules)
        cand.vector = suite.run(cand, sandbox=sandbox, timeout=timeout)
        if cand.vector.total_passes > best_passes:
            best_passes = cand.vector.total_passes
            best = cand
        if best_passes == total:
            break

    if best is None:
        best = seed.clone()
        best_passes = 0
    return BaselineResult(
        solved=best_passes == total and total > 0,
        total_passes=best_passes,
        total_tests=total,
        rounds_used=k,
        best=best,
        trajectory=[best_passes],
    )
