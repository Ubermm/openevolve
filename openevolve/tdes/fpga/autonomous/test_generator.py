"""LLM-based unit testbench generation for decomposed sub-modules."""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import anthropic

from openevolve.tdes.fpga.autonomous.decomposer import Decomposition, SubModule
from openevolve.tdes.fpga.autonomous.prompts import TEST_GEN_SYSTEM, TEST_GEN_USER
from openevolve.tdes.fpga.verilog_runner import simulate

logger = logging.getLogger(__name__)

# Same schema as decomposer: <file name="..." type="testbench">...</file>
_FILE_RE = re.compile(
    r'<file\s+name="[^"]+"\s+type="testbench"[^>]*>\s*\n?(.*?)</file>',
    re.DOTALL,
)
_FALLBACK_RE = re.compile(r"```(?:verilog|Verilog|systemverilog|v)?\s*\n(.*?)```", re.DOTALL)


@dataclass
class GeneratedTest:
    module_name: str
    testbench_source: str
    test_ids: List[str]
    compiles: bool = False
    passes_reference: bool = False
    reference_output: str = ""


def _extract_module_header(source: str) -> str:
    """Extract the full module declaration up to and including ');'."""
    m = re.search(r"(module\s+\w+\s*(?:#\s*\(.*?\))?\s*\(.*?\)\s*;)", source, re.DOTALL)
    if m:
        return m.group(1)
    return source.split("\n")[0]


def _extract_test_ids(source: str) -> List[str]:
    """Extract test_id values from TDES_PASS/TDES_FAIL markers."""
    ids = []
    for m in re.finditer(r'test_id=(\w+)', source):
        tid = m.group(1)
        if tid not in ids:
            ids.append(tid)
    return ids


def generate_tests(
    decomposition: Decomposition,
    system_testbench: str,
    design_description: str,
    *,
    model: str = "claude-sonnet-4-6",
    api_key: str,
    max_retries: int = 3,
) -> List[GeneratedTest]:
    """Generate unit testbenches for each sub-module in the decomposition."""
    client = anthropic.Anthropic(api_key=api_key)
    tests = []

    for i, sub in enumerate(decomposition.sub_modules):
        # Build context about upstream/downstream
        if i == 0:
            context = "This is the first pipeline stage. It receives raw 32-bit IEEE-754 inputs."
        elif i == len(decomposition.sub_modules) - 1:
            context = "This is the last pipeline stage before output packing."
        else:
            prev = decomposition.sub_modules[i - 1]
            nxt = decomposition.sub_modules[i + 1]
            context = (
                f"It receives outputs from `{prev.name}` ({prev.description}) "
                f"and feeds into `{nxt.name}` ({nxt.description})."
            )

        user_prompt = TEST_GEN_USER.format(
            module_name=sub.name,
            port_list=sub.reference_source,
            description=sub.description,
            design_description=design_description,
            context=context,
            system_testbench=system_testbench,
        )

        test = _generate_one_test(
            client, model, sub, user_prompt, max_retries
        )
        tests.append(test)

    return tests


def _generate_one_test(
    client: anthropic.Anthropic,
    model: str,
    sub: SubModule,
    user_prompt: str,
    max_retries: int,
) -> GeneratedTest:
    """Generate and validate a test for one sub-module."""
    compile_error = ""

    for attempt in range(max_retries):
        prompt = user_prompt
        if compile_error:
            prompt += (
                f"\n\n## PREVIOUS ATTEMPT FAILED\n\n"
                f"Fix these errors:\n```\n{compile_error}\n```"
            )

        logger.info(
            "Generating test for %s (attempt %d/%d)",
            sub.name, attempt + 1, max_retries,
        )

        response = client.messages.create(
            model=model,
            max_tokens=8000,
            system=TEST_GEN_SYSTEM,
            messages=[{"role": "user", "content": prompt}],
        )
        response_text = response.content[0].text

        # Extract testbench: try <file> tag first, fall back to code fence
        m = _FILE_RE.search(response_text)
        if not m:
            m = _FALLBACK_RE.search(response_text)
        if not m:
            compile_error = 'No testbench found. Wrap output in <file name="unit_X_tb.v" type="testbench">...</file>'
            continue

        tb_source = m.group(1).strip()

        # Verify TDES markers exist
        if "TDES_PASS" not in tb_source and "TDES_FAIL" not in tb_source:
            compile_error = (
                "Testbench must use TDES_PASS/TDES_FAIL protocol. "
                "Use $display(\"TDES_PASS: test_id=...\") for each passing check."
            )
            continue

        # Compile with the sub-module reference
        sim = simulate(
            {sub.name: sub.reference_source},
            tb_source,
            timeout=30,
        )

        if not sim.compiled:
            compile_error = sim.compile_error or sim.stderr
            logger.warning(
                "Test compilation failed for %s: %s",
                sub.name, compile_error[:300],
            )
            continue

        test_ids = _extract_test_ids(tb_source)

        test = GeneratedTest(
            module_name=sub.name,
            testbench_source=tb_source,
            test_ids=test_ids,
            compiles=True,
        )
        logger.info(
            "Test generated for %s: %d test IDs, compiles OK",
            sub.name, len(test_ids),
        )
        return test

    # Return best effort even if failed
    return GeneratedTest(
        module_name=sub.name,
        testbench_source="",
        test_ids=[],
        compiles=False,
    )


def validate_tests_against_reference(
    tests: List[GeneratedTest],
    decomposition: Decomposition,
) -> Tuple[int, int, List[str]]:
    """Run each generated test against its reference implementation.

    Returns (pass_count, total_count, failure_details).
    """
    passed = 0
    total = 0
    failures = []

    for test in tests:
        if not test.compiles or not test.testbench_source:
            failures.append(f"{test.module_name}: test didn't compile")
            total += 1
            continue

        sub = next(
            (s for s in decomposition.sub_modules if s.name == test.module_name),
            None,
        )
        if not sub:
            failures.append(f"{test.module_name}: sub-module not found in decomposition")
            total += 1
            continue

        sim = simulate(
            {sub.name: sub.reference_source},
            test.testbench_source,
            timeout=30,
        )

        total += 1
        if not sim.compiled:
            failures.append(
                f"{test.module_name}: compile error with reference: {sim.compile_error}"
            )
            continue

        # Count TDES_PASS vs TDES_FAIL in output
        pass_count = len(re.findall(r"TDES_PASS:", sim.stdout))
        fail_count = len(re.findall(r"TDES_FAIL:", sim.stdout))

        test.reference_output = sim.stdout

        if fail_count == 0 and pass_count > 0:
            test.passes_reference = True
            passed += 1
            logger.info(
                "%s: reference passes all %d tests", test.module_name, pass_count
            )
        else:
            # Extract failing test details
            fail_lines = [
                line for line in sim.stdout.split("\n") if "TDES_FAIL" in line
            ]
            detail = "; ".join(fail_lines[:3])
            failures.append(
                f"{test.module_name}: {fail_count} failures on reference: {detail}"
            )
            logger.warning(
                "%s: %d/%d tests fail on reference",
                test.module_name, fail_count, pass_count + fail_count,
            )

    return passed, total, failures
