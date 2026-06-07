"""
Ablation conditions for TDES-CombOpt.

The ablation *controllers* (``AblationController``, ``DiverseScheduleController``,
``SingleAgentFallbackController``) are entirely suite-agnostic — they only touch
the duck-typed ``suite`` interface and the base TDES mechanisms — so they are
reused **unchanged** from the FPGA layer rather than re-implemented. Only the
combopt-specific ``flatten_levels`` (the scalar-fitness ablation) and the
``CONDITIONS`` registry live here.
"""

from __future__ import annotations

from openevolve.tdes.combopt.combopt_suite import CombOptTest, CombOptTestSuite
from openevolve.tdes.fpga.ablation import (  # noqa: F401 - re-exported, suite-agnostic
    AblationController,
    CrossoverStats,
    DiverseScheduleController,
    SingleAgentFallbackController,
)
from openevolve.tdes.types import TestLevel


def flatten_levels(suite: CombOptTestSuite) -> CombOptTestSuite:
    """Return a copy of ``suite`` with every test at UNIT level.

    Collapsing the hierarchy makes lexicographic ordering degenerate to ranking
    by total pass count — the *scalar fitness* ablation — without touching
    selection.
    """
    flat = [
        CombOptTest(
            id=t.id,
            level=TestLevel.UNIT,
            module=t.module,
            description=t.description,
            kind=t.kind,
            payload=dict(t.payload),
            modules=t.modules,
        )
        for t in suite.tests
    ]
    return CombOptTestSuite(
        problem=suite.problem, module_names=list(suite.module_names), tests=flat
    )


# Registry of ablation conditions -> (controller kwargs, suite transform).
CONDITIONS = {
    "tdes_full": (dict(enable_crossover=True, enable_memory=True), None),
    "tdes_no_crossover": (dict(enable_crossover=False, enable_memory=True), None),
    "tdes_no_memory": (dict(enable_crossover=True, enable_memory=False), None),
    "tdes_scalar": (dict(enable_crossover=True, enable_memory=True), flatten_levels),
}
