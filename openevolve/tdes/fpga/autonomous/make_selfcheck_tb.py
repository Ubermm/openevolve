"""Generate self-checking Verilog testbenches for ArchXBench Level-4 benchmarks.

Reads golden_output.json and the original testbench for each design, then
produces a modified testbench (tb_selfcheck.v) that embeds golden values and
checks inline, emitting [PASS]/[FAIL] markers compatible with the TDES
verilog_runner protocol.

Usage:
    python -m openevolve.tdes.fpga.autonomous.make_selfcheck_tb
    python -m openevolve.tdes.fpga.autonomous.make_selfcheck_tb --designs band_pass_fir low_pass_fir
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

LEVEL4_DIR = Path(__file__).resolve().parent.parent / "benchmarks" / "archxbench" / "level-4"

# Design configurations keyed by directory name.
# module_name: the Verilog module under test
# kind: "fir" or "fft"
# mode: for FFT/IFFT, 0=FFT, 1=IFFT
DESIGN_CONFIGS = {
    "band_pass_fir": {
        "module_name": "bandpass_fir",
        "kind": "fir",
        "data_w": 20,
        "tap_cnt": 31,
        "gain_w": 4,
    },
    "high_pass_fir": {
        "module_name": "highpass_fir",
        "kind": "fir",
        "data_w": 20,
        "tap_cnt": 31,
        "gain_w": 4,
    },
    "low_pass_fir": {
        "module_name": "lowpass_fir",
        "kind": "fir",
        "data_w": 20,
        "tap_cnt": 31,
        "gain_w": 4,
    },
    "fft_16pt_iterative": {
        "module_name": "fft16_iterative",
        "kind": "fft",
        "n": 16,
        "data_w": 12,
        "gain_w": 4,
        "mode": 0,
    },
    "ifft_16pt_iterative": {
        "module_name": "ifft16_iterative",
        "kind": "fft",
        "n": 16,
        "data_w": 12,
        "gain_w": 4,
        "mode": 1,
    },
}


def _load_json(path: str):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _signed_literal(width: int, value: int) -> str:
    """Format a signed integer as a Verilog signed literal.

    E.g. ``_signed_literal(20, -5)`` -> ``-20'sd5``
         ``_signed_literal(20, 5)`` -> ``20'sd5``
    """
    if value < 0:
        return f"-{width}'sd{-value}"
    return f"{width}'sd{value}"


def _generate_fir_selfcheck(
    design_dir: Path,
    cfg: dict,
) -> str:
    """Generate self-checking testbench for FIR filter designs."""
    stimuli_path = design_dir / "inputs" / "stimuli.json"
    golden_path = design_dir / "outputs" / "golden_output.json"

    stimuli = _load_json(str(stimuli_path))
    golden = _load_json(str(golden_path))

    module_name = cfg["module_name"]
    data_w = cfg["data_w"]
    tap_cnt = cfg["tap_cnt"]
    gain_w = cfg["gain_w"]
    out_w = data_w + gain_w

    n_stim = len(stimuli)
    n_golden = len(golden)

    # Build the stimuli and golden initializer lines
    stim_init_lines = []
    for i, v in enumerate(stimuli):
        stim_init_lines.append(f"    stimuli[{i}] = {_signed_literal(out_w, v)};")

    golden_init_lines = []
    for i, v in enumerate(golden):
        golden_init_lines.append(f"    golden[{i}] = {_signed_literal(out_w, v)};")

    stim_init = "\n".join(stim_init_lines)
    golden_init = "\n".join(golden_init_lines)

    tb = f"""\
`timescale 1ns/1ps

// Auto-generated self-checking testbench for {module_name}
// Golden values embedded from golden_output.json ({n_golden} samples)

module tb_{module_name}_selfcheck;
  parameter DATA_W  = {data_w};
  parameter TAP_CNT = {tap_cnt};
  parameter GAIN_W  = {gain_w};
  localparam OUT_W  = DATA_W + GAIN_W;

  // Clock and reset
  reg clk = 0, rst;
  always #5 clk = ~clk;

  // DUT I/O
  reg                  valid_in;
  reg  [DATA_W-1:0]    data_in;
  wire                 valid_out;
  wire signed [OUT_W-1:0] data_out;

  // Instantiate DUT
  {module_name} #(
    .DATA_W(DATA_W),
    .TAP_CNT(TAP_CNT),
    .GAIN_W(GAIN_W)
  ) dut (
    .clk(clk), .rst(rst),
    .valid_in(valid_in), .data_in(data_in),
    .valid_out(valid_out), .data_out(data_out)
  );

  // Stimuli and golden data
  integer N_STIM  = {n_stim};
  integer N_GOLD  = {n_golden};
  reg signed [OUT_W-1:0] stimuli [0:{n_stim - 1}];
  reg signed [OUT_W-1:0] golden  [0:{n_golden - 1}];

  integer idx, flush_cnt, out_idx;
  integer pass_count, fail_count;

  initial begin
    // Initialize stimuli
{stim_init}

    // Initialize golden values
{golden_init}

    // Reset sequence
    rst = 1; valid_in = 0; data_in = 0;
    pass_count = 0; fail_count = 0; out_idx = 0;
    #20 rst = 0;

    // Drive input stream; outputs appear one clock after each valid_in.
    // Run N_STIM+1 iterations: the extra iteration captures the last output
    // without injecting a new stimulus (valid_in=0 on the last iteration).
    for (idx = 0; idx <= N_STIM; idx = idx + 1) begin
      @(posedge clk);
      if (idx < N_STIM) begin
        valid_in = 1;
        data_in  = stimuli[idx][DATA_W-1:0];
      end else begin
        valid_in = 0;
      end
      if (valid_out) begin
        if (out_idx < N_GOLD) begin
          if (($signed(data_out) - $signed(golden[out_idx]) <= 1) &&
              ($signed(golden[out_idx]) - $signed(data_out) <= 1))
            $display("[PASS] Test %0d: expected %0d, got %0d", out_idx, golden[out_idx], data_out);
          else begin
            $display("[FAIL] Test %0d: expected %0d, got %0d", out_idx, golden[out_idx], data_out);
            fail_count = fail_count + 1;
          end
          pass_count = pass_count + (($signed(data_out) - $signed(golden[out_idx]) <= 1) &&
                                     ($signed(golden[out_idx]) - $signed(data_out) <= 1) ? 1 : 0);
          out_idx = out_idx + 1;
        end
      end
    end

    // Flush pipeline (up to TAP_CNT + 10 pending outputs)
    for (flush_cnt = 0; flush_cnt < TAP_CNT + 10; flush_cnt = flush_cnt + 1) begin
      @(posedge clk);
      if (valid_out) begin
        if (out_idx < N_GOLD) begin
          if (($signed(data_out) - $signed(golden[out_idx]) <= 1) &&
              ($signed(golden[out_idx]) - $signed(data_out) <= 1))
            $display("[PASS] Test %0d: expected %0d, got %0d", out_idx, golden[out_idx], data_out);
          else begin
            $display("[FAIL] Test %0d: expected %0d, got %0d", out_idx, golden[out_idx], data_out);
            fail_count = fail_count + 1;
          end
          pass_count = pass_count + (($signed(data_out) - $signed(golden[out_idx]) <= 1) &&
                                     ($signed(golden[out_idx]) - $signed(data_out) <= 1) ? 1 : 0);
          out_idx = out_idx + 1;
        end
      end
    end

    // Summary
    if (fail_count == 0 && out_idx == N_GOLD)
      $display("[PASS] All %0d/%0d tests passed", out_idx, N_GOLD);
    else if (out_idx < N_GOLD)
      $display("[FAIL] Only %0d/%0d outputs produced (pass=%0d, fail=%0d)",
               out_idx, N_GOLD, pass_count, fail_count);
    else
      $display("[FAIL] %0d/%0d tests passed", pass_count, N_GOLD);
    $finish;
  end
endmodule
"""
    return tb


def _extract_integers(path: str) -> list[int]:
    """Extract all integers from a file, mimicking Verilog $fscanf %d behaviour.

    Handles both flat JSON arrays ``[1, 2, 3]`` and arbitrary JSON structures
    (e.g. ``{"real": [1,2], "imag": [3,4]}``).  Returns integers in the order
    they appear in the text, which matches how ``$fscanf`` would consume them.
    """
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    return [int(x) for x in re.findall(r"-?\d+", raw)]


def _generate_fft_selfcheck(
    design_dir: Path,
    cfg: dict,
) -> str:
    """Generate self-checking testbench for FFT/IFFT designs."""
    golden_path = design_dir / "outputs" / "golden_output.json"
    stim_real_path = design_dir / "inputs" / "stimuli-real.json"
    stim_imag_path = design_dir / "inputs" / "stimuli-imag.json"

    golden = _load_json(str(golden_path))

    module_name = cfg["module_name"]
    n = cfg["n"]
    data_w = cfg["data_w"]
    gain_w = cfg["gain_w"]
    mode = cfg["mode"]
    out_w = data_w + gain_w

    golden_real = golden["real"]
    golden_imag = golden["imag"]

    # Parse stimuli using $fscanf-compatible integer extraction.
    # Some benchmarks (e.g. ifft) have non-standard formats where
    # stimuli-real.json contains *both* real and imag parts as a JSON
    # object, and stimuli-imag.json is incomplete.
    real_ints = _extract_integers(str(stim_real_path))
    imag_ints = _extract_integers(str(stim_imag_path))

    if len(real_ints) >= 2 * n and len(imag_ints) < n:
        # stimuli-real.json contains both real and imag (e.g. IFFT benchmark).
        # The Verilog TB reads the first N as real; for imag it would hang on
        # the broken file, but the golden output was generated from a correct
        # model so we can take the second N from the real file as imag.
        stim_real = real_ints[:n]
        stim_imag = real_ints[n : 2 * n]
    elif len(real_ints) >= n and len(imag_ints) >= n:
        stim_real = real_ints[:n]
        stim_imag = imag_ints[:n]
    else:
        raise ValueError(
            f"Cannot extract {n} stimuli: "
            f"real file has {len(real_ints)} ints, imag file has {len(imag_ints)} ints"
        )

    assert len(golden_real) == n, f"Expected {n} golden real values, got {len(golden_real)}"
    assert len(golden_imag) == n, f"Expected {n} golden imag values, got {len(golden_imag)}"

    # Build initializer lines for stimuli
    stim_real_init = "\n".join(
        f"    data_real_in[{i}] = {_signed_literal(data_w, v)};"
        for i, v in enumerate(stim_real)
    )
    stim_imag_init = "\n".join(
        f"    data_imag_in[{i}] = {_signed_literal(data_w, v)};"
        for i, v in enumerate(stim_imag)
    )

    # Build golden arrays
    golden_real_init = "\n".join(
        f"    golden_real[{i}] = {_signed_literal(out_w, v)};"
        for i, v in enumerate(golden_real)
    )
    golden_imag_init = "\n".join(
        f"    golden_imag[{i}] = {_signed_literal(out_w, v)};"
        for i, v in enumerate(golden_imag)
    )

    mode_str = "IFFT" if mode == 1 else "FFT"

    tb = f"""\
`timescale 1ns/1ps

// Auto-generated self-checking testbench for {module_name} ({mode_str} mode)
// Golden values embedded from golden_output.json ({n} points)

module tb_{module_name}_selfcheck;
  parameter N      = {n};
  parameter DATA_W = {data_w};
  parameter GAIN_W = {gain_w};
  localparam OUT_W = DATA_W + GAIN_W;

  // Clock & control
  reg clk = 0;
  reg rst;
  reg start;
  reg mode;

  // I/O arrays (unpacked)
  reg  signed [DATA_W-1:0]  data_real_in  [0:N-1];
  reg  signed [DATA_W-1:0]  data_imag_in  [0:N-1];
  wire signed [OUT_W-1:0]   data_real_out [0:N-1];
  wire signed [OUT_W-1:0]   data_imag_out [0:N-1];
  wire                       done;

  // Golden arrays
  reg signed [OUT_W-1:0] golden_real [0:N-1];
  reg signed [OUT_W-1:0] golden_imag [0:N-1];

  // Instantiate DUT
  {module_name} #(
    .N(N),
    .DATA_W(DATA_W),
    .GAIN_W(GAIN_W)
  ) dut (
    .clk          (clk),
    .rst          (rst),
    .start        (start),
    .mode         (mode),
    .data_real_in (data_real_in),
    .data_imag_in (data_imag_in),
    .data_real_out(data_real_out),
    .data_imag_out(data_imag_out),
    .done         (done)
  );

  // 100 MHz clock
  always #5 clk = ~clk;

  integer i;
  integer pass_count, fail_count;
  integer timeout_cnt;

  initial begin
    // Reset
    rst   = 1;
    start = 0;
    mode  = {mode};
    pass_count = 0;
    fail_count = 0;

    // Initialize stimuli
{stim_real_init}
{stim_imag_init}

    // Initialize golden values
{golden_real_init}
{golden_imag_init}

    #20 rst = 0;

    // Start {mode_str}
    @(posedge clk) start = 1;
    @(posedge clk) start = 0;

    // Wait for done with timeout
    timeout_cnt = 0;
    while (!done && timeout_cnt < 10000) begin
      @(posedge clk);
      timeout_cnt = timeout_cnt + 1;
    end

    if (!done) begin
      $display("[FAIL] Timeout: done not asserted after %0d cycles", timeout_cnt);
      $finish;
    end

    // Check each output bin
    for (i = 0; i < N; i = i + 1) begin
      // Check real part
      if (data_real_out[i] === golden_real[i])
        $display("[PASS] Test %0d real: expected %0d, got %0d", i, golden_real[i], data_real_out[i]);
      else begin
        $display("[FAIL] Test %0d real: expected %0d, got %0d", i, golden_real[i], data_real_out[i]);
        fail_count = fail_count + 1;
      end
      pass_count = pass_count + (data_real_out[i] === golden_real[i] ? 1 : 0);

      // Check imaginary part
      if (data_imag_out[i] === golden_imag[i])
        $display("[PASS] Test %0d imag: expected %0d, got %0d", i, golden_imag[i], data_imag_out[i]);
      else begin
        $display("[FAIL] Test %0d imag: expected %0d, got %0d", i, golden_imag[i], data_imag_out[i]);
        fail_count = fail_count + 1;
      end
      pass_count = pass_count + (data_imag_out[i] === golden_imag[i] ? 1 : 0);
    end

    // Summary (2*N total checks: N real + N imag)
    if (fail_count == 0)
      $display("[PASS] All %0d/%0d tests passed", pass_count, 2*N);
    else
      $display("[FAIL] %0d/%0d tests passed", pass_count, 2*N);
    $finish;
  end
endmodule
"""
    return tb


def generate_selfcheck_tb(design_name: str) -> str:
    """Generate a self-checking testbench for the given design.

    Returns the path to the generated tb_selfcheck.v file.
    """
    if design_name not in DESIGN_CONFIGS:
        raise ValueError(
            f"Unknown design '{design_name}'. "
            f"Known designs: {list(DESIGN_CONFIGS.keys())}"
        )

    cfg = DESIGN_CONFIGS[design_name]
    design_dir = LEVEL4_DIR / design_name

    if not design_dir.exists():
        raise FileNotFoundError(f"Design directory not found: {design_dir}")

    golden_path = design_dir / "outputs" / "golden_output.json"
    if not golden_path.exists():
        raise FileNotFoundError(f"Golden output not found: {golden_path}")

    if cfg["kind"] == "fir":
        tb_source = _generate_fir_selfcheck(design_dir, cfg)
    elif cfg["kind"] == "fft":
        tb_source = _generate_fft_selfcheck(design_dir, cfg)
    else:
        raise ValueError(f"Unknown design kind: {cfg['kind']}")

    out_path = design_dir / "tb_selfcheck.v"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(tb_source)

    return str(out_path)


def main():
    parser = argparse.ArgumentParser(
        description="Generate self-checking testbenches for ArchXBench Level-4 benchmarks."
    )
    parser.add_argument(
        "--designs",
        nargs="*",
        default=None,
        help="Design names to process (default: all 5 non-self-checking designs)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available designs and exit",
    )
    args = parser.parse_args()

    if args.list:
        for name, cfg in DESIGN_CONFIGS.items():
            print(f"  {name:25s}  module={cfg['module_name']:20s}  kind={cfg['kind']}")
        return

    designs = args.designs if args.designs else list(DESIGN_CONFIGS.keys())

    for name in designs:
        if name not in DESIGN_CONFIGS:
            print(f"ERROR: Unknown design '{name}'", file=sys.stderr)
            print(f"  Available: {list(DESIGN_CONFIGS.keys())}", file=sys.stderr)
            sys.exit(1)

    print(f"Generating self-checking testbenches for {len(designs)} designs...")

    for name in designs:
        try:
            out_path = generate_selfcheck_tb(name)
            print(f"  OK  {name:25s} -> {out_path}")
        except Exception as e:
            print(f"  ERR {name:25s} -> {e}", file=sys.stderr)

    print("Done.")


if __name__ == "__main__":
    main()
