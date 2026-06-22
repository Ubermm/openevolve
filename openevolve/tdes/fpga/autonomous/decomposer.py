"""LLM-based design decomposition with compilation validation and retry."""

from __future__ import annotations

import json
import logging
import os
import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from openevolve.tdes.fpga.autonomous.prompts import DECOMPOSE_SYSTEM, DECOMPOSE_USER
from openevolve.tdes.fpga.verilog_runner import simulate

logger = logging.getLogger(__name__)

# One regex to rule them all:  <file name="X" type="Y"> ... </file>
_FILE_RE = re.compile(
    r'<file\s+name="([^"]+)"\s+type="([^"]+)">\s*\n(.*?)</file>',
    re.DOTALL,
)
_JSON_RE = re.compile(r"<json>(.*?)</json>", re.DOTALL)


@dataclass
class SubModule:
    name: str
    description: str
    reference_source: str
    skeleton_source: str


@dataclass
class Decomposition:
    top_module_name: str
    top_source: str
    sub_modules: List[SubModule]
    raw_response: str = ""

    @property
    def module_names(self) -> List[str]:
        return [m.name for m in self.sub_modules]

    @property
    def reference_modules(self) -> Dict[str, str]:
        return {m.name: m.reference_source for m in self.sub_modules}

    @property
    def skeleton_modules(self) -> Dict[str, str]:
        return {m.name: m.skeleton_source for m in self.sub_modules}


def _make_skeleton(reference_source: str) -> str:
    """Generate a skeleton from a reference by zeroing all outputs."""
    lines = reference_source.split("\n")
    in_module = False
    header_lines = []
    output_names = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("module "):
            in_module = True
        if in_module:
            header_lines.append(line)
            out_m = re.match(
                r"\s*output\s+(?:reg\s+)?(?:\[[\d:]+\]\s+)?(\w+)", stripped
            )
            if out_m:
                output_names.append(out_m.group(1))
            if ");" in stripped:
                break

    if not header_lines:
        return reference_source

    skeleton = "\n".join(header_lines) + "\n"
    for name in output_names:
        skeleton += f"    assign {name} = 0;\n"
    skeleton += "endmodule\n"
    return skeleton


def _parse_files(response: str) -> Tuple[
    Optional[str], Dict[str, str], Dict[str, str], Dict[str, str]
]:
    """Parse <file> tags. Returns (top_source, references, skeletons, descriptions)."""
    top = None
    refs: Dict[str, str] = {}
    skels: Dict[str, str] = {}
    descs: Dict[str, str] = {}

    for m in _FILE_RE.finditer(response):
        name = m.group(1).replace(".v", "")
        ftype = m.group(2).lower()
        source = m.group(3).strip()
        if ftype == "top":
            top = source
        elif ftype == "reference":
            refs[name] = source
        elif ftype == "skeleton":
            skels[name] = source

    jm = _JSON_RE.search(response)
    if jm:
        try:
            data = json.loads(jm.group(1))
            for entry in data.get("sub_modules", []):
                descs[entry["name"]] = entry.get("description", "")
        except (json.JSONDecodeError, KeyError):
            pass

    return top, refs, skels, descs


def decompose(
    problem_description: str,
    design_specs: str,
    testbench: str,
    *,
    model: str = "claude-sonnet-4-6",
    client,
    max_retries: int = 3,
    top_module_name: str = "fp_mult_pipeline",
) -> Decomposition:
    user_prompt = DECOMPOSE_USER.format(
        problem_description=problem_description,
        design_specs=design_specs,
        testbench=testbench,
        top_module_name=top_module_name,
    )

    error_ctx = ""
    for attempt in range(max_retries):
        prompt = user_prompt
        if error_ctx:
            prompt += (
                f"\n\n## PREVIOUS ATTEMPT FAILED\n\n"
                f"Fix these errors and regenerate ALL files:\n```\n{error_ctx}\n```"
            )

        logger.info("Decomposition attempt %d/%d (model=%s)", attempt + 1, max_retries, model)
        resp = client.messages.create(
            model=model, max_tokens=12000, system=DECOMPOSE_SYSTEM,
            messages=[{"role": "user", "content": prompt}],
        )
        text = resp.content[0].text

        top, refs, skels, descs = _parse_files(text)
        logger.info("Parsed: top=%s, refs=%s, skels=%s", bool(top), list(refs), list(skels))

        if not top:
            error_ctx = "Could not find top module. Wrap it in <file name=\"X.v\" type=\"top\">...</file>"
            continue
        if not refs:
            error_ctx = "Could not find reference modules. Wrap each in <file name=\"X.v\" type=\"reference\">...</file>"
            continue

        # Auto-generate missing skeletons
        for name, src in refs.items():
            if name not in skels:
                skels[name] = _make_skeleton(src)

        # Compile check
        all_mods = dict(refs)
        all_mods[top_module_name] = top
        dummy_tb = "`timescale 1ns/1ps\nmodule compile_check;\ninitial $finish;\nendmodule\n"
        sim = simulate(all_mods, dummy_tb, timeout=30)
        if not sim.compiled:
            error_ctx = sim.compile_error or sim.stderr
            logger.warning("Compilation failed: %s", error_ctx[:200])
            continue

        subs = [
            SubModule(
                name=n,
                description=descs.get(n, f"Sub-module {n}"),
                reference_source=refs[n],
                skeleton_source=skels.get(n, _make_skeleton(refs[n])),
            )
            for n in refs
        ]
        logger.info("Decomposition OK: %d sub-modules (%s)", len(subs), [s.name for s in subs])
        return Decomposition(top_module_name, top, subs, text)

    raise RuntimeError(f"Decomposition failed after {max_retries} attempts: {error_ctx}")


def validate_against_testbench(
    decomposition: Decomposition,
    original_testbench: str,
) -> Tuple[bool, str]:
    modules = dict(decomposition.reference_modules)
    modules[decomposition.top_module_name] = decomposition.top_source
    sim = simulate(modules, original_testbench, timeout=60)
    if not sim.compiled:
        return False, f"COMPILE ERROR: {sim.compile_error}"
    output = sim.stdout
    if "100%" in output or "SUCCESS" in output:
        return True, output
    fail_m = re.search(r"Failed:\s*(\d+)", output)
    if fail_m and int(fail_m.group(1)) == 0:
        return True, output
    return False, output
