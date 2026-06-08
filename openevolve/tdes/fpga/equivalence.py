"""
Formal equivalence checking for TDES-FPGA — the "robust verification" oracle.

The efficiency demo (the AlphaEvolve-TPU analog: rewrite a correct arithmetic
circuit to be *smaller* while staying *functionally identical*) needs more than
simulation, which only samples inputs.  This module proves combinational
equivalence between a candidate and a golden reference with Yosys' miter + SAT
flow, so an area-driven rewrite can be accepted only if it is provably correct
for **every** input.

    read_verilog golden.v ; rename <gtop> gold
    read_verilog cand.v   ; rename <ctop> gate
    miter -equiv -make_assert -flatten gold gate miter
    hierarchy -top miter ; flatten
    sat -verify -prove-asserts -show-ports miter

``sat`` reports "no model found" when the asserted equivalence can never be
violated (EQUIVALENT) and "model found" with a counterexample otherwise.
"""

from __future__ import annotations

import logging
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from openevolve.tdes.fpga.verilog_runner import find_tool

logger = logging.getLogger(__name__)


@dataclass
class EquivResult:
    equivalent: bool
    ok: bool = True  # the check itself ran (tools present, no Verilog error)
    counterexample: str = ""
    error: str = ""
    raw: str = ""


def _module_names(source: str) -> List[str]:
    return re.findall(r"\bmodule\s+([A-Za-z_]\w*)", source)


def check_equivalence(
    candidate: str,
    golden: str,
    *,
    top: str,
    timeout: int = 120,
    yosys_path: Optional[str] = None,
) -> EquivResult:
    """Prove that ``candidate`` is combinationally equivalent to ``golden``.

    Both sources must define a module named ``top`` with identical port lists.
    """
    yosys = yosys_path or find_tool(["yosys"])
    if not yosys:
        return EquivResult(False, ok=False, error="yosys not found on PATH")

    if top not in _module_names(golden):
        return EquivResult(False, ok=False, error=f"golden has no module '{top}'")
    if top not in _module_names(candidate):
        return EquivResult(False, ok=False, error=f"candidate has no module '{top}'")

    with tempfile.TemporaryDirectory(prefix="tdes_equiv_") as tmp:
        gpath = os.path.join(tmp, "golden.v")
        cpath = os.path.join(tmp, "cand.v")
        with open(gpath, "w", encoding="utf-8") as f:
            f.write(golden)
        with open(cpath, "w", encoding="utf-8") as f:
            f.write(candidate)

        # Read each design under a distinct top name, build an equivalence miter
        # (asserts gold.* == gate.* for all primary outputs), and SAT-prove it.
        script = "\n".join(
            [
                f"read_verilog {gpath}",
                f"rename {top} gold",
                "proc; opt_clean",
                f"read_verilog {cpath}",
                f"rename {top} gate",
                "proc; opt_clean",
                "miter -equiv -make_assert -flatten gold gate miter",
                "hierarchy -top miter",
                "flatten; proc; opt -purge",
                "sat -verify -prove-asserts -show-ports -seq 1 miter",
            ]
        )
        spath = os.path.join(tmp, "equiv.ys")
        with open(spath, "w", encoding="utf-8") as f:
            f.write(script)

        try:
            # NB: no -q — quiet mode suppresses the SAT "no model found: SUCCESS!"
            # banner that is the proof-of-equivalence verdict we parse.
            proc = subprocess.run(
                [yosys, "-s", spath],
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=tmp,
            )
        except subprocess.TimeoutExpired:
            return EquivResult(False, ok=False, error=f"equivalence check exceeded {timeout}s")

        out = (proc.stdout or "") + "\n" + (proc.stderr or "")
        return _parse_sat(out, proc.returncode)


def _parse_sat(out: str, returncode: int) -> EquivResult:
    low = out.lower()
    # Yosys `sat -prove-asserts`: asserts are the equivalence claims.
    #   "no model found" / "SUCCESS"  -> asserts unviolatable -> EQUIVALENT
    #   "model found"    / "FAIL"     -> a counterexample exists -> NOT equivalent
    proven = "no model found" in low or "success!" in low or "no counterexample found" in low
    violated = ("model found" in low and "no model found" not in low) or "fail!" in low

    if proven and not violated:
        return EquivResult(True, ok=True, raw=out[-2000:])
    if violated:
        return EquivResult(False, ok=True, counterexample=_extract_cex(out), raw=out[-2000:])

    # Neither marker -> the run failed (syntax/elaboration), not a verdict.
    err = _first_error(out) or "equivalence check produced no verdict"
    return EquivResult(False, ok=False, error=err, raw=out[-2000:])


def _extract_cex(out: str) -> str:
    lines = []
    capture = False
    for line in out.splitlines():
        if "Signal Name" in line or "model found" in line.lower():
            capture = True
        if capture:
            lines.append(line.rstrip())
        if len(lines) > 40:
            break
    return "\n".join(lines)[:1500]


def _first_error(text: str) -> str:
    for line in (text or "").splitlines():
        if "ERROR" in line.upper():
            return line.strip()[:400]
    return ""
