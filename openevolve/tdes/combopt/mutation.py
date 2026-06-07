"""
Heuristic mutation operator for TDES-CombOpt.

``HeuristicLLMMutator`` is the combinatorial-optimization analog of
``openevolve.tdes.mutation.LLMMutator``: same ``propose(...)`` protocol and same
reuse of ``code_utils`` diff/rewrite parsing, but with the combopt heuristic
system prompt, the per-problem contract, and ``language="python"``. The offline
``ScriptedMutator`` from the base package is reused unchanged for tests/ablations.
"""

from __future__ import annotations

import logging
import re
from typing import List, Optional

from openevolve.tdes.combopt import prompts
from openevolve.tdes.mutation import MutationProposal, ScriptedMutator  # noqa: F401 (re-export)
from openevolve.tdes.types import Candidate, FeedbackTuple
from openevolve.utils.code_utils import apply_diff, extract_diffs, parse_full_rewrite

logger = logging.getLogger(__name__)

_SUMMARY_RE = re.compile(r"SUMMARY:\s*(.+)", re.IGNORECASE)
_DEFAULT_DIFF = r"<<<<<<< SEARCH\n(.*?)=======\n(.*?)>>>>>>> REPLACE"


def _extract_summary(response: str, default: str) -> str:
    m = _SUMMARY_RE.search(response)
    return m.group(1).strip() if m else default


class HeuristicLLMMutator:
    """LLM-driven mutator over isolated, class-specialized priority functions."""

    def __init__(
        self,
        llm_ensemble,
        problem_name: str,
        *,
        diff_based: bool = True,
        diff_pattern: Optional[str] = None,
    ):
        self.llm = llm_ensemble
        self.problem_name = problem_name
        self.diff_based = diff_based
        self.diff_pattern = diff_pattern or _DEFAULT_DIFF

    async def propose(
        self,
        *,
        candidate: Candidate,
        module: str,
        feedback: List[FeedbackTuple],
        memory_text: str,
        generation: int,
    ) -> Optional[MutationProposal]:
        source = candidate.modules[module]
        user = prompts.build_user_prompt(
            problem_name=self.problem_name,
            module_name=module,
            module_source=source,
            feedback=feedback,
            memory_text=memory_text,
            diff_based=self.diff_based,
            generation=generation,
        )
        response = await self.llm.generate_with_context(
            system_message=prompts.SYSTEM_MESSAGE_COMBOPT,
            messages=[{"role": "user", "content": user}],
        )
        if not response:
            return None

        approach = _extract_summary(response, default=f"LLM edit to {module}")

        if self.diff_based:
            diffs = extract_diffs(response, self.diff_pattern)
            if not diffs:
                rewritten = parse_full_rewrite(response, "python")
                if rewritten and rewritten.strip() and rewritten != response:
                    return MutationProposal(module, rewritten, approach)
                logger.warning("HeuristicLLMMutator: no diffs/rewrite for module %s", module)
                return None
            new_source = apply_diff(source, response, self.diff_pattern)
            if new_source == source:
                return None
            return MutationProposal(module, new_source, approach)

        rewritten = parse_full_rewrite(response, "python")
        if not rewritten or rewritten == source:
            logger.warning("HeuristicLLMMutator: no full rewrite for module %s", module)
            return None
        return MutationProposal(module, rewritten, approach)
