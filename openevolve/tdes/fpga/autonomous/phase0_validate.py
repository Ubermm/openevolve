"""Phase 0: Validate the auto-decomposer on fp_mult_pipeline.

Runs the full autonomous decomposition + test generation pipeline on the
fp_mult_pipeline Level-4 design where we already have a known-good manual
decomposition for comparison.

Usage (from WSL):
    export ANTHROPIC_API_KEY=$(tr -d '[:space:]' < /mnt/c/Users/halag/Primera/novo/openevolve/.anthropic_key)
    cd /mnt/c/Users/halag/Primera/novo/openevolve
    /opt/openevolve-venv/bin/python -m openevolve.tdes.fpga.autonomous.phase0_validate
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

from openevolve.tdes.fpga.autonomous.orchestrator import run_pipeline

logger = logging.getLogger(__name__)

_BENCH_ROOT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "benchmarks", "archxbench", "level-4",
)

# Known-good manual decomposition for comparison
_MANUAL_MODULES = {"fpm_unpack", "fpm_multiply", "fpm_normalize", "fpm_round_pack", "fpm_special"}
_MANUAL_TEST_COUNT = 59  # 34 UNIT + 25 SYSTEM


def _compare_decomposition(result, decomposition):
    """Compare auto-decomposition to manual ground truth."""
    print("\n" + "=" * 60)
    print("COMPARISON: Auto vs Manual Decomposition")
    print("=" * 60)

    auto_names = set(result.sub_module_names)
    print(f"\nManual modules ({len(_MANUAL_MODULES)}): {sorted(_MANUAL_MODULES)}")
    print(f"Auto modules   ({len(auto_names)}):  {sorted(auto_names)}")

    overlap = auto_names & _MANUAL_MODULES
    auto_only = auto_names - _MANUAL_MODULES
    manual_only = _MANUAL_MODULES - auto_names

    if overlap:
        print(f"\nExact name matches: {sorted(overlap)}")
    if auto_only:
        print(f"Auto-only modules:  {sorted(auto_only)}")
    if manual_only:
        print(f"Manual-only modules: {sorted(manual_only)}")

    # Functional similarity analysis
    print(f"\nModule count: manual={len(_MANUAL_MODULES)}, auto={len(auto_names)}")
    print(f"Name overlap: {len(overlap)}/{len(_MANUAL_MODULES)}")

    if decomposition:
        print("\nSub-module descriptions:")
        for sub in decomposition.sub_modules:
            print(f"  {sub.name}: {sub.description}")


def main():
    parser = argparse.ArgumentParser(description="Phase 0: Auto-decomposer validation")
    parser.add_argument(
        "--design", default="fp_mult_pipeline",
        help="ArchXBench Level-4 design name",
    )
    parser.add_argument(
        "--model", default="claude-sonnet-4-6",
        help="Model for decomposition and test generation",
    )
    parser.add_argument(
        "--output", default="tdes_auto_decompose_phase0",
        help="Output directory",
    )
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

    design_dir = os.path.join(_BENCH_ROOT, args.design)
    if not os.path.isdir(design_dir):
        # Try resolving relative to cwd
        alt = os.path.join(
            "openevolve", "tdes", "fpga", "benchmarks", "archxbench",
            "level-4", args.design,
        )
        if os.path.isdir(alt):
            design_dir = alt
        else:
            print(f"ERROR: Design directory not found: {design_dir}")
            sys.exit(1)

    print("=" * 60)
    print(f"Phase 0: Auto-Decompose Validation")
    print(f"Design:  {args.design}")
    print(f"Model:   {args.model}")
    print(f"Output:  {args.output}")
    print("=" * 60)

    result, decomposition, tests = run_pipeline(
        design_dir,
        model=args.model,
        api_key=api_key,
        output_dir=args.output,
    )

    # Report
    print("\n" + "=" * 60)
    print("PHASE 0 RESULTS")
    print("=" * 60)
    print(f"\nDecomposition:")
    print(f"  Sub-modules: {result.num_sub_modules} ({', '.join(result.sub_module_names)})")
    print(f"  References pass original tb: {'YES' if result.reference_passes_original_tb else 'NO'}")

    print(f"\nTest Generation:")
    print(f"  Tests generated:    {result.tests_generated}")
    print(f"  Tests compile OK:   {result.tests_compile_ok}/{len(tests)}")
    print(f"  Tests pass ref:     {result.tests_pass_reference}/{len(tests)}")

    if result.errors:
        print(f"\nErrors ({len(result.errors)}):")
        for e in result.errors:
            print(f"  - {e[:120]}")

    _compare_decomposition(result, decomposition)

    # Overall verdict
    print("\n" + "=" * 60)
    if (
        result.reference_passes_original_tb
        and result.tests_compile_ok == len(tests)
        and result.tests_pass_reference == len(tests)
    ):
        print("VERDICT: PASS — Auto-decomposer produces correct, testable decomposition")
        print("Proceed to Phase 1 (full experiment infrastructure)")
    elif result.reference_passes_original_tb:
        print("VERDICT: PARTIAL — References correct, some tests need fixing")
        print("Fix test generation prompts before scaling")
    else:
        print("VERDICT: FAIL — References don't pass original testbench")
        print("Fix decomposition prompt before proceeding")
    print("=" * 60)

    # Print original tb output for debugging
    if not result.reference_passes_original_tb and result.original_tb_output:
        print("\nOriginal TB output (first 1000 chars):")
        print(result.original_tb_output[:1000])


if __name__ == "__main__":
    main()
