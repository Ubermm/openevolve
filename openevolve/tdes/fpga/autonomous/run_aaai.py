"""AAAI experiment runner: autonomous decompose-test-evolve across all L4 designs.

5 Conditions (30 LLM calls each to control budget):
  C1: zero_shot_pass5      — 5 independent monolithic generations, pick best
  C2: single_agent_mono    — iterative CEGIS on monolithic design, 30 rounds
  C3: decompose_generate   — auto-decompose, one-shot generate per sub-module
  C4: decompose_single     — auto-decompose, iterative per-module CEGIS, ~30 calls
  C5: decompose_tdes       — auto-decompose, auto-test, full TDES evolution

Usage (from WSL):
    export ANTHROPIC_API_KEY=$(tr -d '[:space:]' < /mnt/c/Users/halag/Primera/novo/openevolve/.anthropic_key)
    cd /mnt/c/Users/halag/Primera/novo/openevolve

    # Smoke test: single cell
    /opt/openevolve-venv/bin/python -m openevolve.tdes.fpga.autonomous.run_aaai \
        --designs fp_mult_pipeline --conditions C5 --seeds 42 --output tdes_aaai_smoke

    # Full experiment
    /opt/openevolve-venv/bin/python -m openevolve.tdes.fpga.autonomous.run_aaai \
        --designs all --conditions all --models claude-sonnet-4-6 --seeds 42 123 456 --output tdes_aaai_results
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import re
import sys
import time
from typing import Dict, List, Optional, Tuple

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

import anthropic

from openevolve.tdes.fpga.autonomous.decomposer import (
    Decomposition,
    decompose,
    validate_against_testbench,
)
from openevolve.tdes.fpga.autonomous.test_generator import (
    GeneratedTest,
    generate_tests,
    validate_tests_against_reference,
)
from openevolve.tdes.fpga.autonomous.orchestrator import (
    build_tdes_suite,
    read_benchmark,
    _extract_top_module_name,
    _extract_design_description,
    _save_outputs,
    PipelineResult,
)
from openevolve.tdes.fpga.verilog_runner import simulate
from openevolve.tdes.fpga.verilog_suite import VerilogTest, VerilogTestSuite
from openevolve.tdes.types import Candidate, TestLevel, TestVector

logger = logging.getLogger(__name__)

_BENCH_ROOT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "benchmarks", "archxbench", "level-4",
)

ALL_DESIGNS = [
    "fp_mult_pipeline",
    "fp_adder_pipeline",
    "fft_16pt_iterative",
    "ifft_16pt_iterative",
    "band_pass_fir",
    "high_pass_fir",
    "low_pass_fir",
]

ALL_CONDITIONS = ["C1", "C2", "C3", "C4", "C5"]

def _prepare_data_dir(design_dir: str) -> Optional[str]:
    """Return design_dir if it contains inputs/ or outputs/ subdirectories."""
    for sub in ("inputs", "outputs"):
        if os.path.isdir(os.path.join(design_dir, sub)):
            return design_dir
    return None


_GEN_SYSTEM = (
    "You are an expert digital design engineer. Write a single synthesizable "
    "Verilog module that implements the described specification. Respond with "
    "the module inside <file name=\"{module}.v\" type=\"top\">...</file> tags "
    "and nothing else."
)

_GEN_SUB_SYSTEM = (
    "You are an expert digital design engineer. Write a single synthesizable "
    "Verilog sub-module that implements the described specification. Respond "
    "with the module inside <file name=\"{module}.v\" type=\"implementation\">"
    "...</file> tags and nothing else."
)

_FILE_RE = re.compile(
    r'<file\s+name="[^"]+"\s+type="[^"]+"\s*>\s*\n?(.*?)</file>',
    re.DOTALL,
)
_FENCE_RE = re.compile(r"```(?:verilog)?\s*\n(.*?)```", re.DOTALL)


def _extract_verilog(text: str) -> Optional[str]:
    m = _FILE_RE.search(text)
    if m:
        return m.group(1).strip()
    m = _FENCE_RE.search(text)
    if m:
        return m.group(1).strip()
    return None


def _count_tb_passes(sim_output: str) -> Tuple[int, int]:
    passes = sim_output.count("[PASS]") + len(re.findall(r"TDES_PASS:", sim_output))
    fails = sim_output.count("[FAIL]") + len(re.findall(r"TDES_FAIL:", sim_output))
    return passes, passes + fails


def _cell_key(design, condition, model, seed):
    model_short = model.replace("claude-", "").split("-202")[0]
    return f"{design}__{condition}__{model_short}__{seed}"


def _load_metrics(path):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {}


def _save_metrics(path, metrics):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    existing = _load_metrics(path)
    existing.update(metrics)
    with open(path, "w") as f:
        json.dump(existing, f, indent=2)


def _save_cell(cell_dir, result):
    os.makedirs(cell_dir, exist_ok=True)
    with open(os.path.join(cell_dir, "result.json"), "w") as f:
        json.dump(result, f, indent=2)


# ---------------------------------------------------------------------------
# C1: Zero-shot Pass@5
# ---------------------------------------------------------------------------

def run_C1(
    top_name: str, testbench: str, model: str,
    client: anthropic.Anthropic, problem_desc: str, design_specs: str,
    data_dir: Optional[str] = None,
) -> dict:
    prompt = (
        f"Module name: {top_name}\n\nSpecification:\n{problem_desc}\n\n"
        f"Interface:\n{design_specs}\n\n"
        f"Write the complete Verilog module."
    )
    best_passes, best_total = 0, 0
    best_source = ""
    for attempt in range(5):
        try:
            resp = client.messages.create(
                model=model, max_tokens=8000,
                system=_GEN_SYSTEM.format(module=top_name),
                messages=[{"role": "user", "content": prompt}],
            )
            source = _extract_verilog(resp.content[0].text)
            if not source:
                continue
            sim = simulate({top_name: source}, testbench, timeout=60, data_dir=data_dir)
            if not sim.compiled:
                continue
            p, t = _count_tb_passes(sim.stdout)
            if p > best_passes:
                best_passes, best_total = p, t
                best_source = source
        except Exception as e:
            logger.warning("C1 attempt %d: %s", attempt, e)

    solved = best_total > 0 and best_passes == best_total
    return {
        "condition": "C1", "llm_calls": 5,
        "best_passes": best_passes, "total_tests": best_total,
        "solved": solved,
    }


# ---------------------------------------------------------------------------
# C2: Single-agent monolithic CEGIS (30 rounds)
# ---------------------------------------------------------------------------

def run_C2(
    top_name: str, testbench: str, model: str,
    client: anthropic.Anthropic, problem_desc: str, design_specs: str,
    data_dir: Optional[str] = None,
) -> dict:
    prompt_base = (
        f"Module name: {top_name}\n\nSpecification:\n{problem_desc}\n\n"
        f"Interface:\n{design_specs}\n\n"
        f"Write the complete Verilog module."
    )
    current_source = ""
    best_passes, best_total = 0, 0
    total_calls = 0

    for rnd in range(30):
        total_calls += 1
        prompt = prompt_base
        if current_source and best_passes < best_total:
            sim = simulate({top_name: current_source}, testbench, timeout=60, data_dir=data_dir)
            if sim.compiled:
                fail_lines = [l for l in sim.stdout.split("\n") if "[FAIL]" in l][:5]
                prompt += (
                    f"\n\n## PREVIOUS ATTEMPT (passed {best_passes}/{best_total})\n\n"
                    f"```verilog\n{current_source}\n```\n\n"
                    f"Failing tests:\n" + "\n".join(fail_lines) +
                    "\n\nFix the implementation to pass all tests."
                )

        try:
            resp = client.messages.create(
                model=model, max_tokens=8000,
                system=_GEN_SYSTEM.format(module=top_name),
                messages=[{"role": "user", "content": prompt}],
            )
            source = _extract_verilog(resp.content[0].text)
            if not source:
                continue
            sim = simulate({top_name: source}, testbench, timeout=60, data_dir=data_dir)
            if not sim.compiled:
                continue
            p, t = _count_tb_passes(sim.stdout)
            if p > best_passes:
                best_passes, best_total = p, t
                current_source = source
            if p == t and t > 0:
                break
        except Exception as e:
            logger.warning("C2 round %d: %s", rnd, e)

    solved = best_total > 0 and best_passes == best_total
    return {
        "condition": "C2", "llm_calls": total_calls,
        "best_passes": best_passes, "total_tests": best_total,
        "solved": solved,
    }


# ---------------------------------------------------------------------------
# C3: Decompose + one-shot generate (no iteration)
# ---------------------------------------------------------------------------

def run_C3(
    top_name: str, testbench: str, model: str,
    api_key: str, problem_desc: str, design_specs: str,
    data_dir: Optional[str] = None,
) -> dict:
    decomp = decompose(
        problem_desc, design_specs, testbench,
        model=model, api_key=api_key, top_module_name=top_name,
    )
    validate_against_testbench(decomp, testbench)  # side-effects only, like C4

    client = anthropic.Anthropic(api_key=api_key)
    total_calls = 1  # decomposition
    modules = {top_name: decomp.top_source}

    for sub in decomp.sub_modules:
        total_calls += 1
        prompt = (
            f"Module name: {sub.name}\n\n"
            f"Description: {sub.description}\n\n"
            f"Module declaration:\n```verilog\n{sub.skeleton_source}\n```\n\n"
            f"Write the complete implementation."
        )
        try:
            resp = client.messages.create(
                model=model, max_tokens=4000,
                system=_GEN_SUB_SYSTEM.format(module=sub.name),
                messages=[{"role": "user", "content": prompt}],
            )
            source = _extract_verilog(resp.content[0].text)
            modules[sub.name] = source if source else sub.skeleton_source
        except Exception as e:
            logger.warning("C3 generate %s: %s", sub.name, e)
            modules[sub.name] = sub.skeleton_source

    sim = simulate(modules, testbench, timeout=60, data_dir=data_dir)
    if not sim.compiled:
        return {
            "condition": "C3", "solved": False, "llm_calls": total_calls,
            "error": f"final compile failed: {(sim.compile_error or '')[:200]}",
            "decomp_modules": decomp.module_names,
        }

    p, t = _count_tb_passes(sim.stdout)
    solved = t > 0 and p == t
    return {
        "condition": "C3", "llm_calls": total_calls,
        "best_passes": p, "total_tests": t,
        "solved": solved, "decomp_modules": decomp.module_names,
    }


# ---------------------------------------------------------------------------
# C4: Decompose + single-agent CEGIS per module (~30 calls total)
# ---------------------------------------------------------------------------

def run_C4(
    top_name: str, testbench: str, model: str,
    api_key: str, problem_desc: str, design_specs: str,
    data_dir: Optional[str] = None,
) -> dict:
    decomp = decompose(
        problem_desc, design_specs, testbench,
        model=model, api_key=api_key, top_module_name=top_name,
    )
    ref_ok, _ = validate_against_testbench(decomp, testbench)

    client = anthropic.Anthropic(api_key=api_key)
    total_calls = 1  # decomposition
    modules = {top_name: decomp.top_source}
    rounds_per_module = max(1, 28 // len(decomp.sub_modules))

    for sub in decomp.sub_modules:
        current_source = sub.skeleton_source
        for rnd in range(rounds_per_module):
            total_calls += 1
            # Test against original TB with current state
            test_modules = dict(modules)
            # Use references for other modules, current for this one
            for other in decomp.sub_modules:
                if other.name == sub.name:
                    test_modules[other.name] = current_source
                elif other.name not in modules or modules.get(other.name) == other.skeleton_source:
                    test_modules[other.name] = other.reference_source
                else:
                    test_modules[other.name] = modules[other.name]

            sim = simulate(test_modules, testbench, timeout=60, data_dir=data_dir)
            feedback = ""
            if sim.compiled:
                fail_lines = [l for l in sim.stdout.split("\n") if "[FAIL]" in l][:5]
                p, t = _count_tb_passes(sim.stdout)
                if p == t and t > 0:
                    break
                feedback = (
                    f"\n\nPrevious attempt passed {p}/{t} tests.\n"
                    f"Failures:\n" + "\n".join(fail_lines)
                )
            elif sim.compile_error:
                feedback = f"\n\nCompilation error:\n{sim.compile_error[:300]}"

            prompt = (
                f"Module name: {sub.name}\n\n"
                f"Description: {sub.description}\n\n"
                f"Current source:\n```verilog\n{current_source}\n```"
                f"{feedback}\n\n"
                f"Write the corrected complete implementation."
            )
            try:
                resp = client.messages.create(
                    model=model, max_tokens=4000,
                    system=_GEN_SUB_SYSTEM.format(module=sub.name),
                    messages=[{"role": "user", "content": prompt}],
                )
                source = _extract_verilog(resp.content[0].text)
                if source:
                    current_source = source
            except Exception as e:
                logger.warning("C4 %s rnd %d: %s", sub.name, rnd, e)

        modules[sub.name] = current_source

    # Final validation
    sim = simulate(modules, testbench, timeout=60, data_dir=data_dir)
    if not sim.compiled:
        return {
            "condition": "C4", "solved": False, "llm_calls": total_calls,
            "error": "final compile failed",
            "decomp_modules": decomp.module_names,
        }

    p, t = _count_tb_passes(sim.stdout)
    solved = t > 0 and p == t
    return {
        "condition": "C4", "llm_calls": total_calls,
        "best_passes": p, "total_tests": t,
        "solved": solved, "decomp_modules": decomp.module_names,
    }


# ---------------------------------------------------------------------------
# C5: Full autonomous decompose-test-evolve
# ---------------------------------------------------------------------------

def run_C5(
    top_name: str, testbench: str, model: str,
    api_key: str, problem_desc: str, design_specs: str,
    cell_dir: str,
    data_dir: Optional[str] = None,
) -> dict:
    decomp = decompose(
        problem_desc, design_specs, testbench,
        model=model, api_key=api_key, top_module_name=top_name,
    )
    design_desc = _extract_design_description(problem_desc)
    tests = generate_tests(
        decomp, testbench, design_desc,
        model=model, api_key=api_key,
    )
    pass_count, total, failures = validate_tests_against_reference(tests, decomp)

    suite, seed_candidate = build_tdes_suite(decomp, tests, testbench)

    from openevolve.tdes.fpga.mutation import VerilogLLMMutator
    from openevolve.tdes.fpga import ablation
    from openevolve.tdes.fpga.config import FPGAConfig
    from openevolve.tdes.fpga.experiments.runner import build_ensemble
    from openevolve.tdes import selection

    cfg_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..", "experiments", "configs", "anthropic_opus.yaml",
    )
    cfg = FPGAConfig.from_yaml(cfg_path)
    cfg.pop_size = 5
    cfg.max_generations = 6
    cfg.random_seed = None  # let seed param handle it

    # Override model in config
    if cfg.llm and cfg.llm.llm.models:
        cfg.llm.llm.models[0].name = model

    from openevolve.tdes.fpga.experiments.runner import _CountingEnsemble

    ensemble = build_ensemble(cfg)
    counting = _CountingEnsemble(ensemble)
    mutator = VerilogLLMMutator(counting, diff_based=False)

    controller = ablation.DiverseScheduleController(
        seed_candidate,
        suite,
        mutator,
        cfg,
        enable_crossover=True,
        enable_memory=True,
    )
    tdes_result = controller.run()

    best = tdes_result.best if tdes_result else seed_candidate
    final_modules = dict(best.modules)
    final_modules[top_name] = decomp.top_source
    sim = simulate(final_modules, testbench, timeout=60, data_dir=data_dir)

    solved = False
    best_passes, total_tests = 0, 0
    if sim.compiled:
        best_passes, total_tests = _count_tb_passes(sim.stdout)
        solved = total_tests > 0 and best_passes == total_tests

    setup_calls = 1 + len(tests)
    return {
        "condition": "C5",
        "solved": solved,
        "decomp_modules": decomp.module_names,
        "tests_compiled": sum(1 for t in tests if t.compiles),
        "tests_pass_ref": pass_count,
        "best_passes": best_passes,
        "total_tests": total_tests,
        "evolution_gens": tdes_result.generations_run if tdes_result else 0,
        "llm_calls": setup_calls + counting.calls,
    }


# ---------------------------------------------------------------------------
# Cell runner
# ---------------------------------------------------------------------------

def run_cell(
    design: str, condition: str, model: str, seed: int,
    api_key: str, output_dir: str,
) -> dict:
    design_dir = os.path.join(_BENCH_ROOT, design)
    if not os.path.isdir(design_dir):
        return {"error": f"Design not found: {design_dir}"}

    problem_desc, design_specs, testbench = read_benchmark(design_dir)
    top_name = _extract_top_module_name(design_specs)
    client = anthropic.Anthropic(api_key=api_key)
    cell_dir = os.path.join(output_dir, design, condition, str(seed))
    data_dir = _prepare_data_dir(design_dir)

    logger.info("=== Cell: %s / %s / %s / seed=%d ===", design, condition, model, seed)
    t0 = time.time()

    try:
        if condition == "C1":
            result = run_C1(top_name, testbench, model, client, problem_desc, design_specs, data_dir)
        elif condition == "C2":
            result = run_C2(top_name, testbench, model, client, problem_desc, design_specs, data_dir)
        elif condition == "C3":
            result = run_C3(top_name, testbench, model, api_key, problem_desc, design_specs, data_dir)
        elif condition == "C4":
            result = run_C4(top_name, testbench, model, api_key, problem_desc, design_specs, data_dir)
        elif condition == "C5":
            result = run_C5(top_name, testbench, model, api_key, problem_desc, design_specs, cell_dir, data_dir)
        else:
            result = {"error": f"Unknown condition: {condition}"}
    except Exception as e:
        logger.exception("Cell failed: %s", e)
        result = {"error": str(e)}

    result["design"] = design
    result["model"] = model
    result["seed"] = seed
    result["wall_seconds"] = round(time.time() - t0, 1)
    _save_cell(cell_dir, result)
    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="AAAI Experiment Runner")
    parser.add_argument("--designs", nargs="+", default=["fp_mult_pipeline"])
    parser.add_argument("--conditions", nargs="+", default=["C5"])
    parser.add_argument("--models", nargs="+", default=["claude-sonnet-4-6"])
    parser.add_argument("--seeds", nargs="+", type=int, default=[42])
    parser.add_argument("--output", default="tdes_aaai_results")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )

    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        key_file = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "..", "..", "..", ".anthropic_key",
        )
        if os.path.exists(key_file):
            with open(key_file) as f:
                api_key = f.read().strip()
    if not api_key:
        print("ERROR: Set ANTHROPIC_API_KEY or place key in .anthropic_key")
        sys.exit(1)

    if args.designs == ["all"]:
        args.designs = ALL_DESIGNS
    if args.conditions == ["all"]:
        args.conditions = ALL_CONDITIONS

    metrics_path = os.path.join(args.output, "metrics.json")
    metrics = _load_metrics(metrics_path)

    total_cells = len(args.designs) * len(args.conditions) * len(args.models) * len(args.seeds)
    done = 0

    for design in args.designs:
        for condition in args.conditions:
            for model in args.models:
                for seed in args.seeds:
                    key = _cell_key(design, condition, model, seed)
                    if key in metrics and not metrics[key].get("error"):
                        logger.info("Skipping completed cell: %s", key)
                        done += 1
                        continue

                    result = run_cell(design, condition, model, seed, api_key, args.output)
                    metrics[key] = result
                    _save_metrics(metrics_path, metrics)
                    done += 1
                    logger.info(
                        "Progress: %d/%d cells (%.0f%%)",
                        done, total_cells, 100 * done / total_cells,
                    )

    # Summary
    print("\n" + "=" * 70)
    print("EXPERIMENT COMPLETE")
    print("=" * 70)
    solved_count = sum(1 for v in metrics.values() if v.get("solved"))
    total = len(metrics)
    print(f"Cells: {total}, Solved: {solved_count}/{total}")
    for key, val in sorted(metrics.items()):
        status = "SOLVED" if val.get("solved") else "FAILED"
        p = val.get("best_passes", "?")
        t = val.get("total_tests", "?")
        w = val.get("wall_seconds", "?")
        print(f"  {key}: {status} ({p}/{t}) [{w}s]")


if __name__ == "__main__":
    main()
