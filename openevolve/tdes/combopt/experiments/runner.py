"""
Core experiment driver for TDES-CombOpt.

Runs one (problem, condition, seed) cell and returns a
:class:`~openevolve.tdes.fpga.metrics.RunMetrics` (reused unchanged — it is
generic over the hierarchical TestVector). Conditions cover the TDES ablation
variants (via the suite-agnostic ``AblationController`` family) plus the
``single_agent`` and ``pass5`` baselines.

Two mutation modes:
  * **llm** — build an ``LLMEnsemble`` from the config (real experiments).
  * **scripted** — use the offline reference mutator (validates harness mechanics
    without an API key). Baselines require an LLM and are skipped in scripted mode.
"""

from __future__ import annotations

import copy
import logging
import os
from typing import List, Optional

from openevolve.tdes.combopt import ablation, baselines, benchmark_loader
from openevolve.tdes.combopt.mutation import HeuristicLLMMutator
from openevolve.tdes.config import TDESConfig
from openevolve.tdes.fpga import metrics

logger = logging.getLogger(__name__)

TDES_CONDITIONS = list(ablation.CONDITIONS)
BASELINE_CONDITIONS = ["single_agent", "pass5"]
ALL_CONDITIONS = TDES_CONDITIONS + BASELINE_CONDITIONS


def build_ensemble(config: TDESConfig):
    if config.llm is None or not config.llm.llm.models:
        raise ValueError("LLM mode requires a config with an `llm:` section")
    from openevolve.llm.ensemble import LLMEnsemble

    return LLMEnsemble(config.llm.llm.models)


def run_cell(
    problem: str,
    condition: str,
    config: TDESConfig,
    *,
    seed: int = 0,
    ensemble=None,
    scripted: bool = False,
    diverse_schedule: bool = True,
    loader_kwargs: Optional[dict] = None,
) -> Optional[metrics.RunMetrics]:
    """Run a single experiment cell."""
    seed_cand, suite, ref_mutator = benchmark_loader.load_problem(
        problem, with_mutator=True, **(loader_kwargs or {})
    )
    cfg = _clone_config(config, seed)

    if condition in ablation.CONDITIONS:
        kwargs, transform = ablation.CONDITIONS[condition]
        run_suite = transform(suite) if transform else suite
        mutator = (
            ref_mutator
            if scripted
            else HeuristicLLMMutator(ensemble, problem, diff_based=cfg.diff_based)
        )
        if mutator is None:
            return None
        # DiverseScheduleController randomizes per-candidate module order so the
        # population develops the complementary coverage crossover grafts; the
        # SingleAgentFallback behavior is folded in via the base family. We use
        # DiverseSchedule for the multi-module portfolios here.
        controller_cls = (
            ablation.DiverseScheduleController if diverse_schedule else ablation.AblationController
        )
        controller = controller_cls(seed_cand, run_suite, mutator, cfg, **kwargs)
        result = controller.run()
        return metrics.from_result(
            problem,
            condition,
            seed,
            result,
            total_tests=len(run_suite.tests),
            crossover=controller.crossover_stats.as_dict(),
        )

    if condition in BASELINE_CONDITIONS:
        if scripted or ensemble is None:
            logger.info("skip baseline %s for %s (needs LLM)", condition, problem)
            return None
        if condition == "single_agent":
            br = baselines.single_agent_repair(
                seed_cand,
                suite,
                ensemble,
                problem,
                rounds=cfg.max_generations,
                timeout=cfg.suite_timeout,
                sandbox=cfg.sandbox,
            )
        else:  # pass5
            br = baselines.pass_at_k(
                seed_cand,
                suite,
                ensemble,
                problem,
                k=5,
                timeout=cfg.suite_timeout,
                sandbox=cfg.sandbox,
            )
        return _baseline_metrics(problem, condition, seed, br)

    raise ValueError(f"unknown condition: {condition}")


def run_matrix(
    problems: List[str],
    conditions: List[str],
    config: TDESConfig,
    *,
    seeds: List[int],
    scripted: bool = False,
    diverse_schedule: bool = True,
    loader_kwargs: Optional[dict] = None,
) -> List[metrics.RunMetrics]:
    """Run the full (problem x condition x seed) matrix."""
    ensemble = None if scripted else build_ensemble(config)
    results: List[metrics.RunMetrics] = []
    for problem in problems:
        for condition in conditions:
            for seed in seeds:
                try:
                    rm = run_cell(
                        problem,
                        condition,
                        config,
                        seed=seed,
                        ensemble=ensemble,
                        scripted=scripted,
                        diverse_schedule=diverse_schedule,
                        loader_kwargs=loader_kwargs,
                    )
                except Exception as e:  # keep the sweep alive
                    logger.warning("cell %s/%s seed=%s failed: %s", problem, condition, seed, e)
                    rm = None
                if rm is not None:
                    results.append(rm)
                    logger.info(
                        "%s [%s] seed=%s -> %d/%d %s",
                        problem,
                        condition,
                        seed,
                        rm.total_passes,
                        rm.total_tests,
                        "SOLVED" if rm.solved else "",
                    )
    return results


def _clone_config(config: TDESConfig, seed: int) -> TDESConfig:
    cfg = copy.copy(config)
    cfg.random_seed = (config.random_seed or 0) + seed
    cfg.output_dir = os.path.join(config.output_dir, f"seed_{seed}")
    return cfg


def _baseline_metrics(problem, condition, seed, br) -> metrics.RunMetrics:
    return metrics.RunMetrics(
        design=problem,
        condition=condition,
        seed=seed,
        solved=br.solved,
        total_passes=br.total_passes,
        total_tests=br.total_tests,
        generations_run=br.rounds_used,
        escalated=False,
        trajectory=br.trajectory,
        crossover=None,
    )
