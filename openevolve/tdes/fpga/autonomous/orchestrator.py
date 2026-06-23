"""Full autonomous pipeline: spec -> decompose -> test -> evolve -> validate."""

from __future__ import annotations

import json
import logging
import os
import re
from dataclasses import asdict, dataclass, field
from typing import Dict, List, Optional, Tuple

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
from openevolve.tdes.fpga.verilog_runner import simulate
from openevolve.tdes.fpga.verilog_suite import VerilogTest, VerilogTestSuite
from openevolve.tdes.types import Candidate, TestLevel

logger = logging.getLogger(__name__)


@dataclass
class PipelineResult:
    design: str
    model: str
    decomposition_calls: int = 0
    decomposition_retries: int = 0
    num_sub_modules: int = 0
    sub_module_names: List[str] = field(default_factory=list)
    test_generation_calls: int = 0
    tests_generated: int = 0
    tests_compile_ok: int = 0
    tests_pass_reference: int = 0
    reference_passes_original_tb: bool = False
    original_tb_output: str = ""
    errors: List[str] = field(default_factory=list)


def read_benchmark(design_dir: str) -> Tuple[str, str, str]:
    """Read ArchXBench benchmark files.

    Returns (problem_desc, design_specs, testbench).
    design_specs includes README.md content if present (L5/L6 have
    kernel coefficients and constants there).

    Prefers ``tb_selfcheck.v`` (self-checking, inline [PASS]/[FAIL]) over the
    original testbench.  Falls back to ``tb.v`` or ``tb_<design>.v``.
    """
    def _read(name):
        path = os.path.join(design_dir, name)
        with open(path, encoding="utf-8") as f:
            return f.read()

    # Prefer self-checking testbench if available
    selfcheck_path = os.path.join(design_dir, "tb_selfcheck.v")
    if os.path.exists(selfcheck_path):
        tb_path = selfcheck_path
    else:
        tb_path = os.path.join(design_dir, "tb.v")
        if not os.path.exists(tb_path):
            for f in os.listdir(design_dir):
                if f.startswith("tb_") and f.endswith(".v"):
                    tb_path = os.path.join(design_dir, f)
                    break

    with open(tb_path, encoding="utf-8") as f:
        testbench = f.read()

    design_specs = _read("design-specs.txt")

    # Append README.md if present (L5/L6 have kernel coefficients there)
    readme_path = os.path.join(design_dir, "README.md")
    if os.path.exists(readme_path):
        with open(readme_path, encoding="utf-8") as f:
            readme = f.read()
        design_specs += "\n\n## Additional Notes (README)\n\n" + readme

    return (
        _read("problem-description.txt"),
        design_specs,
        testbench,
    )


def _extract_top_module_name(design_specs: str) -> str:
    """Extract the module name from the design specs."""
    m = re.search(r"Module Name:\s*(\w+)", design_specs)
    if m:
        return m.group(1)
    m = re.search(r"module\s+(\w+)", design_specs)
    if m:
        return m.group(1)
    return "design_top"


def _extract_design_description(problem_desc: str) -> str:
    """Extract a one-line description from problem-description.txt."""
    for line in problem_desc.split("\n"):
        if line.strip().startswith("Title:"):
            return line.strip().replace("Title:", "").strip()
    return problem_desc.split("\n")[0].strip()


def run_pipeline(
    design_dir: str,
    *,
    model: str = "claude-sonnet-4-6",
    api_key: str,
    output_dir: Optional[str] = None,
) -> Tuple[PipelineResult, Optional[Decomposition], List[GeneratedTest]]:
    """Run the full autonomous decomposition + test generation pipeline.

    This does NOT run TDES evolution — it produces the decomposition and tests
    that TDES would use. Phase 0 validation only.

    Returns (result, decomposition, tests).
    """
    result = PipelineResult(design=design_dir, model=model)

    # Step 1: Read benchmark
    problem_desc, design_specs, testbench = read_benchmark(design_dir)
    top_name = _extract_top_module_name(design_specs)
    design_desc = _extract_design_description(problem_desc)

    logger.info("=== Stage 1: Decompose (%s, model=%s) ===", top_name, model)

    # Step 2: Decompose
    try:
        decomposition = decompose(
            problem_desc,
            design_specs,
            testbench,
            model=model,
            api_key=api_key,
            top_module_name=top_name,
        )
    except RuntimeError as e:
        result.errors.append(f"Decomposition failed: {e}")
        return result, None, []

    result.decomposition_calls = 1  # TODO: track retries
    result.num_sub_modules = len(decomposition.sub_modules)
    result.sub_module_names = decomposition.module_names

    # Step 3: Validate references against original testbench
    logger.info("=== Stage 2: Validate references against original tb ===")
    ref_ok, ref_output = validate_against_testbench(decomposition, testbench)
    result.reference_passes_original_tb = ref_ok
    result.original_tb_output = ref_output

    if not ref_ok:
        logger.warning("References FAIL original testbench:\n%s", ref_output[:500])
        result.errors.append("References fail original testbench")
    else:
        logger.info("References PASS original testbench")

    # Step 4: Generate unit tests
    logger.info("=== Stage 3: Generate unit tests ===")
    tests = generate_tests(
        decomposition,
        testbench,
        design_desc,
        model=model,
        api_key=api_key,
    )

    result.test_generation_calls = len(tests)
    result.tests_generated = sum(len(t.test_ids) for t in tests)
    result.tests_compile_ok = sum(1 for t in tests if t.compiles)

    # Step 5: Validate tests against references
    logger.info("=== Stage 4: Validate tests against references ===")
    pass_count, total, failures = validate_tests_against_reference(tests, decomposition)
    result.tests_pass_reference = pass_count

    for f in failures:
        result.errors.append(f)

    # Save outputs if output_dir specified
    if output_dir:
        _save_outputs(output_dir, decomposition, tests, result)

    return result, decomposition, tests


def build_tdes_suite(
    decomposition: Decomposition,
    tests: List[GeneratedTest],
    original_testbench: str,
) -> Tuple[VerilogTestSuite, Candidate]:
    """Build a VerilogTestSuite + seed Candidate from auto-generated decomposition.

    This creates the same structure as the manual loader but from LLM output.
    Returns (suite, seed_candidate).
    """
    verilog_tests = []

    # Unit tests from generated testbenches
    for gen_test in tests:
        if not gen_test.compiles or not gen_test.testbench_source:
            continue
        for tid in gen_test.test_ids:
            desc = f"{gen_test.module_name}: auto-generated test {tid}"
            verilog_tests.append(
                VerilogTest(
                    id=tid,
                    level=TestLevel.UNIT,
                    module=gen_test.module_name,
                    description=desc,
                    testbench_source=gen_test.testbench_source,
                    modules=[gen_test.module_name],
                )
            )

    # System tests from original testbench
    system_combined = decomposition.top_source + "\n" + original_testbench
    # The original tb uses [PASS]/[FAIL] format, not TDES protocol.
    # We add the original tb as a single system-level test.
    verilog_tests.append(
        VerilogTest(
            id="system_original_tb",
            level=TestLevel.SYSTEM,
            module=decomposition.sub_modules[-1].name if decomposition.sub_modules else "",
            description="Original ArchXBench system testbench (ground truth)",
            testbench_source=system_combined,
            modules=decomposition.module_names,
        )
    )

    suite = VerilogTestSuite(
        module_names=decomposition.module_names,
        tests=verilog_tests,
        top_module=decomposition.top_module_name,
        isolate_modules=True,
    )

    seed = Candidate(
        modules=decomposition.skeleton_modules,
        metadata={
            "origin": "auto_decompose_seed",
            "design": decomposition.top_module_name,
        },
    )

    return suite, seed


def _save_outputs(
    output_dir: str,
    decomposition: Decomposition,
    tests: List[GeneratedTest],
    result: PipelineResult,
):
    """Save decomposition outputs to disk for inspection."""
    os.makedirs(output_dir, exist_ok=True)

    # Save top module
    top_path = os.path.join(output_dir, f"{decomposition.top_module_name}.v")
    with open(top_path, "w", encoding="utf-8") as f:
        f.write(decomposition.top_source)

    # Save reference and skeleton sub-modules
    ref_dir = os.path.join(output_dir, "reference")
    seed_dir = os.path.join(output_dir, "seed")
    test_dir = os.path.join(output_dir, "tests")
    os.makedirs(ref_dir, exist_ok=True)
    os.makedirs(seed_dir, exist_ok=True)
    os.makedirs(test_dir, exist_ok=True)

    for sub in decomposition.sub_modules:
        with open(os.path.join(ref_dir, f"{sub.name}.v"), "w", encoding="utf-8") as f:
            f.write(sub.reference_source)
        with open(os.path.join(seed_dir, f"{sub.name}.v"), "w", encoding="utf-8") as f:
            f.write(sub.skeleton_source)

    # Save generated tests
    for test in tests:
        if test.testbench_source:
            with open(
                os.path.join(test_dir, f"unit_{test.module_name}_tb.v"),
                "w",
                encoding="utf-8",
            ) as f:
                f.write(test.testbench_source)

    # Save raw LLM response
    with open(os.path.join(output_dir, "decompose_response.txt"), "w", encoding="utf-8") as f:
        f.write(decomposition.raw_response)

    # Save result summary
    summary = {
        "design": result.design,
        "model": result.model,
        "decomposition_calls": result.decomposition_calls,
        "num_sub_modules": result.num_sub_modules,
        "sub_module_names": result.sub_module_names,
        "tests_generated": result.tests_generated,
        "tests_compile_ok": result.tests_compile_ok,
        "tests_pass_reference": result.tests_pass_reference,
        "reference_passes_original_tb": result.reference_passes_original_tb,
        "errors": result.errors,
    }
    with open(os.path.join(output_dir, "pipeline_result.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    logger.info("Outputs saved to %s", output_dir)
