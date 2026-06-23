"""AAAI experiment runner: autonomous decompose-test-evolve across all L4 designs.

5 Conditions (30 LLM calls each to control budget):
  C1: zero_shot_pass5      — 5 independent monolithic generations, pick best
  C2: single_agent_mono    — iterative CEGIS on monolithic design, 30 rounds
  C3: decompose_generate   — auto-decompose, one-shot generate per sub-module
  C4: decompose_single     — auto-decompose, iterative per-module CEGIS, ~30 calls
  C5: decompose_tdes       — auto-decompose, auto-test, full TDES evolution

Usage (from WSL):
    # Anthropic models (Claude)
    export ANTHROPIC_API_KEY=$(tr -d '[:space:]' < /mnt/c/Users/halag/Primera/novo/openevolve/.anthropic_key)
    # OpenAI models (GPT-4o, o3-mini, etc.) — optional, auto-loaded from .openai_key
    export OPENAI_API_KEY=$(tr -d '[:space:]' < /mnt/c/Users/halag/Primera/novo/openevolve/.openai_key)

    cd /mnt/c/Users/halag/Primera/novo/openevolve

    # Anthropic (original)
    /opt/openevolve-venv/bin/python -m openevolve.tdes.fpga.autonomous.run_aaai \
        --designs fp_mult_pipeline --conditions C4 --seeds 42 --models claude-sonnet-4-6

    # OpenAI
    /opt/openevolve-venv/bin/python -m openevolve.tdes.fpga.autonomous.run_aaai \
        --designs fp_mult_pipeline --conditions C4 --seeds 42 --models gpt-4o

    # Full experiment
    /opt/openevolve-venv/bin/python -m openevolve.tdes.fpga.autonomous.run_aaai \
        --designs all --conditions all --models claude-sonnet-4-6 gpt-4o --seeds 42 123 456 --output tdes_aaai_results
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

from openevolve.tdes.fpga.autonomous.client import LLMClient
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

_ARCHX_ROOT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "benchmarks", "archxbench",
)

_LEVEL_DESIGNS = {
    "L2": [
        "aes128_single_round", "cla_32bit_pipe", "dadda_mult_pipe",
        "rca_32bit_pipe", "wallace_tree_mult_pipe",
    ],
    "L3": [
        "fp_adder", "fp_multiplier", "gauss_siedel",
        "gradient_descent", "newton_raphson_polynomial", "newton_raphson_sqrt",
    ],
    "L4": [
        "fp_mult_pipeline", "fp_adder_pipeline",
        "fft_16pt_iterative", "ifft_16pt_iterative",
        "band_pass_fir", "high_pass_fir", "low_pass_fir",
    ],
    "L5": [
        "conv1d", "conv2d", "dct_idct_8pt_pipelined",
        "harris_corner_detection", "systolic_gemm", "unsharp_mask",
    ],
    "L6": [
        "aes_decryption", "aes_encryption", "conv_3d",
        "fft_streaming_64pt", "fp_band_pass_fir", "fp_high_pass_fir",
        "fp_low_pass_fir", "multich_conv2d", "quantized_matmul",
    ],
}

_LEVEL_DIRS = {
    "L2": os.path.join(_ARCHX_ROOT, "level-2"),
    "L3": os.path.join(_ARCHX_ROOT, "level-3"),
    "L4": os.path.join(_ARCHX_ROOT, "level-4"),
    "L5": os.path.join(_ARCHX_ROOT, "level-5"),
    "L6": os.path.join(_ARCHX_ROOT, "level-6"),
}

ALL_DESIGNS = _LEVEL_DESIGNS["L4"]  # backwards compat

ALL_CONDITIONS = ["C1", "C2", "C3", "C4", "C4i", "C4i-noStudy", "C4i-stateless", "C4i-rawFail", "C4i-noRef", "C4tl", "C5"]

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

_C4I_SYSTEM = (
    "You are an expert digital design engineer solving a Verilog sub-module "
    "through iterative investigation and refinement. You study specifications "
    "carefully, reason about bit-level behavior, analyze test failures by "
    "computing expected vs actual values, and fix root causes — not symptoms.\n\n"
    "When writing Verilog, wrap it in "
    "<file name=\"{module}.v\" type=\"implementation\">...</file> tags.\n"
    "When analyzing (no code change needed), just explain your reasoning."
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
    """Count PASS/FAIL from simulation output. Works for all testbench formats."""
    passes = len(re.findall(r'\bPASS\b', sim_output))
    fails = len(re.findall(r'\bFAIL\b', sim_output))
    return passes, passes + fails


def _has_icarus_sensitivity_warning(sim_stderr: str) -> bool:
    """Detect 'always @* found no sensitivities' — causes all-x outputs."""
    return "found no sensitivities" in (sim_stderr or "")


def _run_golden_comparison(data_dir: str, sim_workdir: str) -> Tuple[int, int, str]:
    """Run post-sim golden comparison for L5/L6 designs.

    Compares outputs/dut_output.json against outputs/golden_output.json.
    Returns (passes, total, detail_string).
    """
    import json as _json

    dut_path = os.path.join(sim_workdir, "outputs", "dut_output.json")
    golden_path = os.path.join(data_dir, "outputs", "golden_output.json")

    if not os.path.exists(dut_path):
        return 0, 1, "DUT output file not written"
    if not os.path.exists(golden_path):
        return 0, 1, "Golden output file not found"

    try:
        dut = _json.load(open(dut_path))
        golden = _json.load(open(golden_path))
    except Exception as e:
        return 0, 1, f"JSON parse error: {e}"

    # Flatten if nested
    if isinstance(dut, dict):
        dut = list(dut.values())
    if isinstance(golden, dict):
        golden = list(golden.values())
    if isinstance(dut, list) and dut and isinstance(dut[0], list):
        dut = [x for row in dut for x in row]
    if isinstance(golden, list) and golden and isinstance(golden[0], list):
        golden = [x for row in golden for x in row]

    n = min(len(golden), len(dut))
    if n == 0:
        return 0, 1, "Empty output"

    mismatches = []
    for i in range(n):
        try:
            if abs(float(golden[i]) - float(dut[i])) > 1:
                mismatches.append((i, golden[i], dut[i]))
        except (TypeError, ValueError):
            if golden[i] != dut[i]:
                mismatches.append((i, golden[i], dut[i]))

    passes = n - len(mismatches)
    detail_lines = [f"FAIL idx={i}: ref={r} dut={d}" for i, r, d in mismatches[:10]]
    if not mismatches:
        detail = f"PASS All {n} samples match"
    else:
        detail = f"FAIL {len(mismatches)}/{n} mismatches\n" + "\n".join(detail_lines)
    return passes, n, detail


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

    # Save Verilog sources as individual files (for qualitative analysis)
    sources = result.pop("_sources", None)
    decomp_desc = result.pop("_decomp_descriptions", None)
    top_source = result.pop("_top_source", None)

    if sources:
        src_dir = os.path.join(cell_dir, "verilog")
        os.makedirs(src_dir, exist_ok=True)
        for name, src in sources.items():
            with open(os.path.join(src_dir, f"{name}.v"), "w", encoding="utf-8") as f:
                f.write(src)

    if decomp_desc:
        with open(os.path.join(cell_dir, "decomposition.json"), "w") as f:
            json.dump({"top_source_file": "verilog/" + (result.get("decomp_modules", ["top"])[0] if result.get("decomp_modules") else "top") + ".v",
                       "sub_modules": decomp_desc}, f, indent=2)

    with open(os.path.join(cell_dir, "result.json"), "w") as f:
        json.dump(result, f, indent=2)


def _sub_context(decomp, index: int) -> str:
    """Describe a sub-module's position in the pipeline."""
    subs = decomp.sub_modules
    if index == 0:
        nxt = subs[1] if len(subs) > 1 else None
        ctx = "First pipeline stage — receives raw inputs from the top module."
        if nxt:
            ctx += f" Feeds into `{nxt.name}` ({nxt.description})."
        return ctx
    if index == len(subs) - 1:
        prev = subs[index - 1]
        return f"Final pipeline stage. Receives from `{prev.name}` ({prev.description}). Output goes to top module."
    prev, nxt = subs[index - 1], subs[index + 1]
    return (
        f"Receives from `{prev.name}` ({prev.description}), "
        f"feeds into `{nxt.name}` ({nxt.description})."
    )


# ---------------------------------------------------------------------------
# C1: Zero-shot Pass@5
# ---------------------------------------------------------------------------

def run_C1(
    top_name: str, testbench: str, model: str,
    client: LLMClient, problem_desc: str, design_specs: str,
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
    client: LLMClient, problem_desc: str, design_specs: str,
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
    client: LLMClient, problem_desc: str, design_specs: str,
    data_dir: Optional[str] = None,
) -> dict:
    decomp = decompose(
        problem_desc, design_specs, testbench,
        model=model, client=client, top_module_name=top_name,
    )
    validate_against_testbench(decomp, testbench)  # side-effects only, like C4

    total_calls = 1  # decomposition
    modules = {top_name: decomp.top_source}

    for i, sub in enumerate(decomp.sub_modules):
        total_calls += 1
        context = _sub_context(decomp, i)
        prompt = (
            f"Module name: {sub.name}\n\n"
            f"Description: {sub.description}\n\n"
            f"Pipeline context: {context}\n\n"
            f"## Full Design Specification\n\n{design_specs}\n\n"
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
    client: LLMClient, problem_desc: str, design_specs: str,
    data_dir: Optional[str] = None,
) -> dict:
    decomp = decompose(
        problem_desc, design_specs, testbench,
        model=model, client=client, top_module_name=top_name,
    )
    ref_ok, _ = validate_against_testbench(decomp, testbench)

    total_calls = 1  # decomposition
    modules = {top_name: decomp.top_source}
    rounds_per_module = max(1, 28 // len(decomp.sub_modules))

    for idx, sub in enumerate(decomp.sub_modules):
        current_source = sub.skeleton_source
        context = _sub_context(decomp, idx)
        for rnd in range(rounds_per_module):
            total_calls += 1
            test_modules = dict(modules)
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
                fail_lines = [l for l in sim.stdout.split("\n") if "[FAIL]" in l][:10]
                p, t = _count_tb_passes(sim.stdout)
                if p == t and t > 0:
                    break
                feedback = (
                    f"\n\n## Test Results ({p}/{t} passed)\n\n"
                    f"Failing tests:\n" + "\n".join(fail_lines)
                )
            elif sim.compile_error:
                feedback = f"\n\n## Compilation Error\n\n```\n{sim.compile_error[:500]}\n```"

            prompt = (
                f"Module name: {sub.name}\n\n"
                f"Description: {sub.description}\n\n"
                f"Pipeline context: {context}\n\n"
                f"## Full Design Specification\n\n{design_specs}\n\n"
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
    _artifacts = {
        "_sources": dict(modules),
        "_decomp_descriptions": {s.name: s.description for s in decomp.sub_modules},
        "_top_source": decomp.top_source,
    }
    sim = simulate(modules, testbench, timeout=60, data_dir=data_dir)
    if not sim.compiled:
        return {
            "condition": "C4", "solved": False, "llm_calls": total_calls,
            "error": "final compile failed",
            "decomp_modules": decomp.module_names,
            **_artifacts,
        }

    p, t = _count_tb_passes(sim.stdout)
    solved = t > 0 and p == t
    return {
        "condition": "C4", "llm_calls": total_calls,
        "best_passes": p, "total_tests": t,
        "solved": solved, "decomp_modules": decomp.module_names,
        **_artifacts,
    }


# ---------------------------------------------------------------------------
# C4i: Decompose + Investigative CEGIS (multi-turn, reason-then-fix)
# ---------------------------------------------------------------------------

def _parse_fail_details(sim_stdout: str) -> str:
    """Extract structured failure info: test ID, expected, got values."""
    lines = []
    for line in sim_stdout.split("\n"):
        if re.search(r'\bFAIL\b', line):
            lines.append(line.strip())
    if not lines:
        return "No specific failure lines found in output."
    return "\n".join(lines[:15])


def _build_study_prompt(sub, context: str, design_specs: str,
                        testbench: str, reference_source: str) -> str:
    """Build the initial study prompt — the model investigates before coding."""
    return (
        f"## Your Task\n\n"
        f"You need to implement the Verilog module `{sub.name}`.\n"
        f"Before writing any code, study the specification and reference "
        f"implementation carefully. Identify the key algorithmic steps, "
        f"bit widths, edge cases, and timing requirements.\n\n"
        f"## Module Description\n\n{sub.description}\n\n"
        f"## Pipeline Context\n\n{context}\n\n"
        f"## Full Design Specification\n\n{design_specs}\n\n"
        f"## Reference Implementation (from the decomposer)\n\n"
        f"This may have bugs — treat it as a starting point, not gospel:\n"
        f"```verilog\n{reference_source}\n```\n\n"
        f"## System Testbench (ground truth)\n\n"
        f"Your module will be tested against this testbench. Study it to "
        f"understand the exact expected I/O behavior:\n"
        f"```verilog\n{testbench[:3000]}\n```\n\n"
        f"## Instructions\n\n"
        f"1. First, explain your understanding of what this module must do — "
        f"key computations, bit widths, special cases.\n"
        f"2. Then write your implementation inside "
        f"<file name=\"{sub.name}.v\" type=\"implementation\">...</file> tags."
    )


def _build_fix_prompt_diagnostic(sub, current_source: str, sim_result,
                                 pass_count: int, total_tests: int,
                                 design_specs: str) -> str:
    """Diagnostic fix prompt — reason about WHY, then fix."""
    if not sim_result.compiled:
        error_info = sim_result.compile_error or sim_result.stderr or "Unknown"
        return (
            f"## Compilation Failed\n\n"
            f"```\n{error_info[:800]}\n```\n\n"
            f"## Current Source\n\n```verilog\n{current_source}\n```\n\n"
            f"Analyze the compilation error. Identify the exact line and "
            f"root cause. Then provide the corrected implementation in "
            f"<file name=\"{sub.name}.v\" type=\"implementation\">...</file> tags."
        )

    fail_details = _parse_fail_details(sim_result.stdout)
    return (
        f"## Test Results: {pass_count}/{total_tests} passed\n\n"
        f"### Failing Tests\n\n```\n{fail_details}\n```\n\n"
        f"## Current Source\n\n```verilog\n{current_source}\n```\n\n"
        f"## Design Specification (for reference)\n\n{design_specs}\n\n"
        f"## Instructions\n\n"
        f"1. **Diagnose**: Look at the expected vs actual values in the "
        f"failing tests. What specific computation is wrong? Is it a "
        f"bit-width issue, rounding error, sign handling, special case, "
        f"or pipeline timing problem?\n"
        f"2. **Root cause**: Identify the exact lines in your current source "
        f"that produce the wrong result.\n"
        f"3. **Fix**: Provide the corrected implementation in "
        f"<file name=\"{sub.name}.v\" type=\"implementation\">...</file> tags."
    )


def _build_fix_prompt_raw(sub, current_source: str, sim_result,
                          pass_count: int, total_tests: int,
                          design_specs: str) -> str:
    """Raw fix prompt — just show fail lines, ask to fix (C4-style)."""
    if not sim_result.compiled:
        error_info = sim_result.compile_error or sim_result.stderr or "Unknown"
        return (
            f"Compilation error:\n{error_info[:500]}\n\n"
            f"Current source:\n```verilog\n{current_source}\n```\n\n"
            f"Write the corrected complete implementation."
        )

    fail_lines = [l.strip() for l in sim_result.stdout.split("\n")
                  if re.search(r'\bFAIL\b', l)][:10]
    return (
        f"Previous attempt passed {pass_count}/{total_tests} tests.\n"
        f"Failures:\n" + "\n".join(fail_lines) + "\n\n"
        f"Current source:\n```verilog\n{current_source}\n```\n\n"
        f"Write the corrected complete implementation."
    )


def run_C4i(
    top_name: str, testbench: str, model: str,
    client: LLMClient, problem_desc: str, design_specs: str,
    data_dir: Optional[str] = None,
    *,
    condition_label: str = "C4i",
    study: bool = True,
    multi_turn: bool = True,
    diagnostic: bool = True,
    show_ref: bool = True,
) -> dict:
    """Investigative CEGIS with ablation flags.

    Flags:
        study: include initial study phase (spec + reference analysis)
        multi_turn: preserve conversation history across rounds
        diagnostic: use structured diagnostic feedback (vs raw fail lines)
        show_ref: show reference implementation in study prompt
    """
    decomp = decompose(
        problem_desc, design_specs, testbench,
        model=model, client=client, top_module_name=top_name,
    )
    ref_ok, _ = validate_against_testbench(decomp, testbench)

    total_calls = 1  # decomposition
    modules = {top_name: decomp.top_source}
    rounds_per_module = max(2, 28 // len(decomp.sub_modules))
    module_solve_rounds = {}
    build_fix = _build_fix_prompt_diagnostic if diagnostic else _build_fix_prompt_raw

    for idx, sub in enumerate(decomp.sub_modules):
        context = _sub_context(decomp, idx)
        current_source = sub.skeleton_source
        conversation = []

        if study:
            ref_src = sub.reference_source if show_ref else "(not provided)"
            study_prompt = _build_study_prompt(
                sub, context, design_specs, testbench, ref_src,
            )
            conversation.append({"role": "user", "content": study_prompt})

            try:
                total_calls += 1
                resp = client.messages.create(
                    model=model, max_tokens=8000,
                    system=_C4I_SYSTEM.format(module=sub.name),
                    messages=conversation,
                )
                reply = resp.content[0].text
                conversation.append({"role": "assistant", "content": reply})
                source = _extract_verilog(reply)
                if source:
                    current_source = source
            except Exception as e:
                logger.warning("C4i %s study: %s", sub.name, e)
                current_source = sub.reference_source
        else:
            current_source = sub.reference_source

        best_passes, best_total = 0, 0
        for rnd in range(rounds_per_module - (1 if study else 0)):
            test_modules = dict(modules)
            for other in decomp.sub_modules:
                if other.name == sub.name:
                    test_modules[other.name] = current_source
                elif other.name not in modules or modules.get(other.name) == other.skeleton_source:
                    test_modules[other.name] = other.reference_source
                else:
                    test_modules[other.name] = modules[other.name]

            sim = simulate(test_modules, testbench, timeout=60, data_dir=data_dir)
            if sim.compiled:
                p, t = _count_tb_passes(sim.stdout)
                if p > best_passes:
                    best_passes, best_total = p, t
                if p == t and t > 0:
                    module_solve_rounds[sub.name] = rnd + 1
                    logger.info("C4i %s solved at round %d (%d/%d)", sub.name, rnd + 1, p, t)
                    break
            else:
                p, t = 0, 0

            fix_prompt = build_fix(sub, current_source, sim, p, t, design_specs)

            if not multi_turn:
                conversation = []
            conversation.append({"role": "user", "content": fix_prompt})

            try:
                total_calls += 1
                resp = client.messages.create(
                    model=model, max_tokens=8000,
                    system=_C4I_SYSTEM.format(module=sub.name),
                    messages=conversation,
                )
                reply = resp.content[0].text
                conversation.append({"role": "assistant", "content": reply})
                source = _extract_verilog(reply)
                if source:
                    current_source = source
            except Exception as e:
                logger.warning("C4i %s rnd %d: %s", sub.name, rnd, e)
                if len(conversation) > 8:
                    conversation = conversation[:2] + conversation[-4:]

        modules[sub.name] = current_source

    # Final validation
    sim = simulate(modules, testbench, timeout=60, data_dir=data_dir)
    if not sim.compiled:
        return {
            "condition": condition_label, "solved": False, "llm_calls": total_calls,
            "error": "final compile failed",
            "decomp_modules": decomp.module_names,
            "module_solve_rounds": module_solve_rounds,
            "_sources": dict(modules),
            "_decomp_descriptions": {s.name: s.description for s in decomp.sub_modules},
            "_top_source": decomp.top_source,
        }

    p, t = _count_tb_passes(sim.stdout)
    solved = t > 0 and p == t
    return {
        "condition": condition_label, "llm_calls": total_calls,
        "best_passes": p, "total_tests": t,
        "solved": solved, "decomp_modules": decomp.module_names,
        "module_solve_rounds": module_solve_rounds,
        "_sources": dict(modules),
        "_decomp_descriptions": {s.name: s.description for s in decomp.sub_modules},
        "_top_source": decomp.top_source,
    }


# ---------------------------------------------------------------------------
# C4tl: Trace-Lifted CEGIS — fault localization via reference-gating
# ---------------------------------------------------------------------------

_C4TL_SYSTEM = (
    "You are an expert digital design engineer fixing a specific Verilog "
    "sub-module. You have been told exactly which module is causing system "
    "test failures. Study the failing traces, compare with the reference "
    "implementation, and fix the root cause.\n\n"
    "When writing Verilog, wrap it in "
    "<file name=\"{module}.v\" type=\"implementation\">...</file> tags."
)


def _localize_fault(
    top_name: str, decomp, modules: Dict[str, str],
    testbench: str, data_dir: Optional[str],
) -> Tuple[Optional[str], Dict[str, Tuple[int, int]]]:
    """Trace-lift: swap each candidate with reference to find the culprit.

    Returns (worst_module_name, {module: (passes, total)}).
    """
    scores = {}
    for sub in decomp.sub_modules:
        test_modules = dict(modules)
        test_modules[top_name] = decomp.top_source
        # Swap this module back to reference, keep others as candidates
        for other in decomp.sub_modules:
            if other.name == sub.name:
                test_modules[other.name] = other.reference_source
            # else keep candidate
        sim = simulate(test_modules, testbench, timeout=60, data_dir=data_dir)
        if sim.compiled:
            p, t = _count_tb_passes(sim.stdout)
            scores[sub.name] = (p, t)
        else:
            scores[sub.name] = (0, 0)

    if not scores:
        return None, scores

    # The module whose reference-swap gives the BIGGEST improvement is the culprit
    # (swapping the bad module with reference fixes the most tests)
    # Equivalently: the module with the highest score when swapped out
    best_swap = max(scores.items(), key=lambda x: x[1][0])
    # But we want the module that's CAUSING failures, which is the one
    # whose swap-to-reference helps the most
    # If all scores are equal, pick the one with lowest absolute score
    # when it's the candidate (need to test each as sole candidate too)

    # Simpler: test each module as the ONLY candidate (all others reference)
    # Already done above. The module with lowest score = worst culprit
    # Wait — we swapped each to reference. High score = this module was fine.
    # Low score = even with this swapped to reference, still failing = other modules bad.
    # The module whose swap MOST improves the score is the culprit.

    # Get baseline (all candidates)
    baseline_modules = dict(modules)
    baseline_modules[top_name] = decomp.top_source
    baseline_sim = simulate(baseline_modules, testbench, timeout=60, data_dir=data_dir)
    if baseline_sim.compiled:
        baseline_p, baseline_t = _count_tb_passes(baseline_sim.stdout)
    else:
        baseline_p, baseline_t = 0, 0

    # Improvement = score_with_ref_swap - baseline
    improvements = {}
    for name, (p, t) in scores.items():
        improvements[name] = p - baseline_p

    if not improvements:
        return None, scores

    culprit = max(improvements, key=improvements.get)
    # Only localize if swapping actually helps
    if improvements[culprit] <= 0:
        return None, scores

    return culprit, scores


def run_C4tl(
    top_name: str, testbench: str, model: str,
    client: "LLMClient", problem_desc: str, design_specs: str,
    data_dir: Optional[str] = None,
) -> dict:
    """Trace-Lifted CEGIS: decompose, validate reference, localize faults, repair.

    1. Decompose into sub-modules; reference must pass system TB
    2. Generate candidate implementations for all sub-modules
    3. Run full system — if passes, done
    4. Trace-lift: swap each candidate with reference to find culprit
    5. Repair only the culprit module with targeted feedback
    6. Repeat until solved or budget exhausted
    """
    # Step 1: Decompose and validate reference
    decomp = decompose(
        problem_desc, design_specs, testbench,
        model=model, client=client, top_module_name=top_name,
    )
    total_calls = 1

    # Validate reference composition passes testbench
    ref_modules = {top_name: decomp.top_source}
    ref_modules.update(decomp.reference_modules)
    ref_sim = simulate(ref_modules, testbench, timeout=60, data_dir=data_dir)
    ref_passes, ref_total = 0, 0
    if ref_sim.compiled:
        ref_passes, ref_total = _count_tb_passes(ref_sim.stdout)

    ref_ok = ref_total > 0 and ref_passes == ref_total
    if not ref_ok:
        logger.warning("C4tl: reference composition failed (%d/%d). Proceeding anyway.",
                       ref_passes, ref_total)

    # Step 2: Generate initial candidates via study prompt
    modules = {top_name: decomp.top_source}
    module_solve_rounds = {}

    for idx, sub in enumerate(decomp.sub_modules):
        context = _sub_context(decomp, idx)
        study_prompt = _build_study_prompt(
            sub, context, design_specs, testbench, sub.reference_source,
        )
        try:
            total_calls += 1
            resp = client.messages.create(
                model=model, max_tokens=8000,
                system=_C4TL_SYSTEM.format(module=sub.name),
                messages=[{"role": "user", "content": study_prompt}],
            )
            source = _extract_verilog(resp.content[0].text)
            modules[sub.name] = source if source else sub.reference_source
        except Exception as e:
            logger.warning("C4tl %s initial: %s", sub.name, e)
            modules[sub.name] = sub.reference_source

    # Step 3-5: Test → localize → repair loop
    max_rounds = 28 - len(decomp.sub_modules)
    best_passes, best_total = 0, 0

    for rnd in range(max_rounds):
        # Step 3: Full system test
        full_modules = dict(modules)
        full_modules[top_name] = decomp.top_source
        sim = simulate(full_modules, testbench, timeout=60, data_dir=data_dir)

        if sim.compiled:
            p, t = _count_tb_passes(sim.stdout)
            if p > best_passes:
                best_passes, best_total = p, t
            if p == t and t > 0:
                logger.info("C4tl SOLVED at round %d (%d/%d)", rnd + 1, p, t)
                break
        else:
            p, t = 0, 0

        # Check for Icarus sensitivity warning
        if _has_icarus_sensitivity_warning(sim.stderr):
            logger.warning("C4tl: Icarus 'no sensitivities' warning — may cause all-x")

        # Step 4: Trace-lift to localize fault
        culprit, scores = _localize_fault(
            top_name, decomp, modules, testbench, data_dir,
        )

        if culprit is None:
            # Can't localize — repair the module with worst pass rate
            # Fall back to sequential repair
            culprit = min(
                (s.name for s in decomp.sub_modules),
                key=lambda n: scores.get(n, (0, 0))[0],
            )

        culprit_sub = next((s for s in decomp.sub_modules if s.name == culprit), None)
        if culprit_sub is None:
            break

        logger.info("C4tl round %d: culprit=%s (scores: %s)", rnd + 1, culprit,
                    {n: f"{p}/{t}" for n, (p, t) in scores.items()})

        # Step 5: Repair the culprit with targeted feedback
        fail_details = _parse_fail_details(sim.stdout) if sim.compiled else (
            sim.compile_error or sim.stderr or "Unknown compilation error"
        )[:500]

        score_summary = "\n".join(
            f"  {n}: {sp}/{st} (swapped to reference)"
            for n, (sp, st) in sorted(scores.items())
        )

        repair_prompt = (
            f"## Fault Localization Result\n\n"
            f"The system testbench passed {p}/{t} tests. Trace-lifted analysis "
            f"identified **`{culprit}`** as the module causing failures.\n\n"
            f"### Per-Module Scores (each tested with reference for all others)\n\n"
            f"```\n{score_summary}\n```\n\n"
            f"### System Test Failures\n\n```\n{fail_details}\n```\n\n"
            f"### Current Implementation of `{culprit}`\n\n"
            f"```verilog\n{modules[culprit]}\n```\n\n"
            f"### Reference Implementation (oracle)\n\n"
            f"```verilog\n{culprit_sub.reference_source}\n```\n\n"
            f"### Design Specification\n\n{design_specs}\n\n"
            f"## Task\n\n"
            f"1. Compare your implementation with the reference to find the bug\n"
            f"2. Fix **only** `{culprit}` — preserve exact module name and ports\n"
            f"3. Provide the corrected implementation in "
            f"<file name=\"{culprit}.v\" type=\"implementation\">...</file> tags."
        )

        try:
            total_calls += 1
            resp = client.messages.create(
                model=model, max_tokens=8000,
                system=_C4TL_SYSTEM.format(module=culprit),
                messages=[{"role": "user", "content": repair_prompt}],
            )
            source = _extract_verilog(resp.content[0].text)
            if source:
                modules[culprit] = source
        except Exception as e:
            logger.warning("C4tl repair %s rnd %d: %s", culprit, rnd, e)

    # Final validation
    _artifacts = {
        "_sources": dict(modules),
        "_decomp_descriptions": {s.name: s.description for s in decomp.sub_modules},
        "_top_source": decomp.top_source,
    }
    final_modules = dict(modules)
    final_modules[top_name] = decomp.top_source
    sim = simulate(final_modules, testbench, timeout=60, data_dir=data_dir)
    if not sim.compiled:
        return {
            "condition": "C4tl", "solved": False, "llm_calls": total_calls,
            "error": "final compile failed",
            "decomp_modules": decomp.module_names,
            "ref_passes": ref_passes, "ref_total": ref_total,
            "module_solve_rounds": module_solve_rounds,
            **_artifacts,
        }

    p, t = _count_tb_passes(sim.stdout)
    solved = t > 0 and p == t
    return {
        "condition": "C4tl", "llm_calls": total_calls,
        "best_passes": p, "total_tests": t,
        "solved": solved, "decomp_modules": decomp.module_names,
        "ref_passes": ref_passes, "ref_total": ref_total,
        "module_solve_rounds": module_solve_rounds,
        **_artifacts,
    }


# ---------------------------------------------------------------------------
# C5: Full autonomous decompose-test-evolve
# ---------------------------------------------------------------------------

def run_C5(
    top_name: str, testbench: str, model: str,
    client: LLMClient, problem_desc: str, design_specs: str,
    cell_dir: str,
    data_dir: Optional[str] = None,
) -> dict:
    decomp = decompose(
        problem_desc, design_specs, testbench,
        model=model, client=client, top_module_name=top_name,
    )
    design_desc = _extract_design_description(problem_desc)
    tests = generate_tests(
        decomp, testbench, design_desc,
        model=model, client=client,
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

def _resolve_design_dir(design: str) -> str:
    """Find the benchmark directory for a design name across all ArchXBench levels."""
    for level, designs in _LEVEL_DESIGNS.items():
        if design in designs:
            return os.path.join(_LEVEL_DIRS[level], design)
    # Fallback: search all level dirs
    for level, ddir in _LEVEL_DIRS.items():
        candidate = os.path.join(ddir, design)
        if os.path.isdir(candidate):
            return candidate
    return os.path.join(_LEVEL_DIRS["L4"], design)


def run_cell(
    design: str, condition: str, model: str, seed: int,
    anthropic_key: str, openai_key: str, output_dir: str,
) -> dict:
    design_dir = _resolve_design_dir(design)
    if not os.path.isdir(design_dir):
        return {"error": f"Design not found: {design_dir}"}

    problem_desc, design_specs, testbench = read_benchmark(design_dir)
    top_name = _extract_top_module_name(design_specs)
    client = LLMClient.from_model(model, anthropic_key=anthropic_key, openai_key=openai_key)
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
            result = run_C3(top_name, testbench, model, client, problem_desc, design_specs, data_dir)
        elif condition == "C4":
            result = run_C4(top_name, testbench, model, client, problem_desc, design_specs, data_dir)
        elif condition == "C4i":
            result = run_C4i(top_name, testbench, model, client, problem_desc, design_specs, data_dir)
        elif condition == "C4i-noStudy":
            result = run_C4i(top_name, testbench, model, client, problem_desc, design_specs, data_dir,
                             condition_label="C4i-noStudy", study=False)
        elif condition == "C4i-stateless":
            result = run_C4i(top_name, testbench, model, client, problem_desc, design_specs, data_dir,
                             condition_label="C4i-stateless", multi_turn=False)
        elif condition == "C4i-rawFail":
            result = run_C4i(top_name, testbench, model, client, problem_desc, design_specs, data_dir,
                             condition_label="C4i-rawFail", diagnostic=False)
        elif condition == "C4i-noRef":
            result = run_C4i(top_name, testbench, model, client, problem_desc, design_specs, data_dir,
                             condition_label="C4i-noRef", show_ref=False)
        elif condition == "C4tl":
            result = run_C4tl(top_name, testbench, model, client, problem_desc, design_specs, data_dir)
        elif condition == "C5":
            result = run_C5(top_name, testbench, model, client, problem_desc, design_specs, cell_dir, data_dir)
        else:
            result = {"error": f"Unknown condition: {condition}"}
    except Exception as e:
        logger.exception("Cell failed: %s", e)
        result = {"error": str(e)}

    result["design"] = design
    result["model"] = model
    result["seed"] = seed
    result["wall_seconds"] = round(time.time() - t0, 1)
    result["total_input_tokens"] = client.total_input_tokens
    result["total_output_tokens"] = client.total_output_tokens
    _save_cell(cell_dir, result)
    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

_metrics_lock = threading.Lock()


def main():
    parser = argparse.ArgumentParser(description="AAAI Experiment Runner")
    parser.add_argument("--designs", nargs="+", default=["fp_mult_pipeline"],
                        help="Design names or 'all'. Use 'L2', 'L3', 'L4' to select by level.")
    parser.add_argument("--conditions", nargs="+", default=["C4i"])
    parser.add_argument("--models", nargs="+", default=["claude-sonnet-4-6"])
    parser.add_argument("--seeds", nargs="+", type=int, default=[42])
    parser.add_argument("--output", default="tdes_aaai_results")
    parser.add_argument("--parallel", type=int, default=4,
                        help="Max concurrent cells (0 = sequential)")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )

    # Load Anthropic key
    anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not anthropic_key:
        key_file = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "..", "..", "..", ".anthropic_key",
        )
        if os.path.exists(key_file):
            with open(key_file) as f:
                anthropic_key = f.read().strip()

    # Load OpenAI key (optional — only needed for gpt-* / o*-series models)
    openai_key = os.environ.get("OPENAI_API_KEY", "")
    if not openai_key:
        oai_file = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "..", "..", "..", ".openai_key",
        )
        if os.path.exists(oai_file):
            with open(oai_file) as f:
                openai_key = f.read().strip()

    if not anthropic_key and not openai_key:
        print("ERROR: No API key found. Set ANTHROPIC_API_KEY / OPENAI_API_KEY or place keys in .anthropic_key / .openai_key")
        sys.exit(1)

    # Expand level shorthands and "all"
    expanded_designs = []
    for d in args.designs:
        if d.upper() in _LEVEL_DESIGNS:
            expanded_designs.extend(_LEVEL_DESIGNS[d.upper()])
        elif d == "all":
            for level_designs in _LEVEL_DESIGNS.values():
                expanded_designs.extend(level_designs)
        else:
            expanded_designs.append(d)
    args.designs = expanded_designs
    if args.conditions == ["all"]:
        args.conditions = ALL_CONDITIONS

    metrics_path = os.path.join(args.output, "metrics.json")
    metrics = _load_metrics(metrics_path)

    # Build work list (skip completed cells)
    work = []
    skipped = 0
    for design in args.designs:
        for condition in args.conditions:
            for model in args.models:
                for seed in args.seeds:
                    key = _cell_key(design, condition, model, seed)
                    if key in metrics and not metrics[key].get("error"):
                        skipped += 1
                        continue
                    work.append((design, condition, model, seed, key))

    total_cells = len(work) + skipped
    logger.info("Total: %d cells (%d to run, %d already done)", total_cells, len(work), skipped)

    if not work:
        print("All cells already completed.")
        return

    done = skipped

    def _run_and_save(item):
        nonlocal done
        design, condition, model, seed, key = item
        result = run_cell(design, condition, model, seed, anthropic_key, openai_key, args.output)
        with _metrics_lock:
            metrics[key] = result
            _save_metrics(metrics_path, metrics)
            done += 1
            logger.info("Progress: %d/%d cells (%.0f%%) — %s: %s (%s/%s)",
                        done, total_cells, 100 * done / total_cells,
                        key, "SOLVED" if result.get("solved") else "FAILED",
                        result.get("best_passes", "?"), result.get("total_tests", "?"))
        return key, result

    max_workers = max(1, args.parallel) if args.parallel else 1

    if max_workers == 1:
        for item in work:
            _run_and_save(item)
    else:
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(_run_and_save, item): item for item in work}
            for future in as_completed(futures):
                try:
                    future.result()
                except Exception as e:
                    item = futures[future]
                    logger.error("Cell %s crashed: %s", item[4], e)

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
