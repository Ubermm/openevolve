`timescale 1ns/1ps

// Auto-generated self-checking testbench for ifft16_iterative (IFFT mode)
// Golden values embedded from golden_output.json (16 points)

module tb_ifft16_iterative_selfcheck;
  parameter N      = 16;
  parameter DATA_W = 12;
  parameter GAIN_W = 4;
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
  ifft16_iterative #(
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
    mode  = 1;
    pass_count = 0;
    fail_count = 0;

    // Initialize stimuli
    data_real_in[0] = 12'sd35;
    data_real_in[1] = -12'sd32;
    data_real_in[2] = -12'sd13;
    data_real_in[3] = 12'sd3;
    data_real_in[4] = 12'sd5;
    data_real_in[5] = 12'sd5;
    data_real_in[6] = 12'sd6;
    data_real_in[7] = 12'sd6;
    data_real_in[8] = 12'sd6;
    data_real_in[9] = 12'sd6;
    data_real_in[10] = 12'sd6;
    data_real_in[11] = 12'sd5;
    data_real_in[12] = 12'sd5;
    data_real_in[13] = 12'sd3;
    data_real_in[14] = -12'sd13;
    data_real_in[15] = -12'sd32;
    data_imag_in[0] = 12'sd0;
    data_imag_in[1] = -12'sd60;
    data_imag_in[2] = -12'sd51;
    data_imag_in[3] = -12'sd12;
    data_imag_in[4] = -12'sd8;
    data_imag_in[5] = -12'sd5;
    data_imag_in[6] = -12'sd3;
    data_imag_in[7] = -12'sd1;
    data_imag_in[8] = 12'sd0;
    data_imag_in[9] = 12'sd1;
    data_imag_in[10] = 12'sd3;
    data_imag_in[11] = 12'sd5;
    data_imag_in[12] = 12'sd8;
    data_imag_in[13] = 12'sd12;
    data_imag_in[14] = 12'sd51;
    data_imag_in[15] = 12'sd60;

    // Initialize golden values
    golden_real[0] = 16'sd0;
    golden_real[1] = 16'sd6;
    golden_real[2] = 16'sd11;
    golden_real[3] = 16'sd12;
    golden_real[4] = 16'sd10;
    golden_real[5] = 16'sd7;
    golden_real[6] = 16'sd5;
    golden_real[7] = 16'sd4;
    golden_real[8] = 16'sd4;
    golden_real[9] = 16'sd5;
    golden_real[10] = 16'sd5;
    golden_real[11] = 16'sd3;
    golden_real[12] = -16'sd2;
    golden_real[13] = -16'sd8;
    golden_real[14] = -16'sd13;
    golden_real[15] = -16'sd15;
    golden_imag[0] = 16'sd0;
    golden_imag[1] = 16'sd0;
    golden_imag[2] = 16'sd0;
    golden_imag[3] = 16'sd0;
    golden_imag[4] = 16'sd0;
    golden_imag[5] = 16'sd0;
    golden_imag[6] = 16'sd0;
    golden_imag[7] = 16'sd0;
    golden_imag[8] = 16'sd0;
    golden_imag[9] = 16'sd0;
    golden_imag[10] = 16'sd0;
    golden_imag[11] = 16'sd0;
    golden_imag[12] = 16'sd0;
    golden_imag[13] = 16'sd0;
    golden_imag[14] = 16'sd0;
    golden_imag[15] = 16'sd0;

    #20 rst = 0;

    // Start IFFT
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
    // Tolerance: +-2 LSB.
    // The golden was computed by float IFFT on float stimuli (stimuli_float.json), then
    // rounded to integers. The integer testbench stimuli are round(float_stimuli), which
    // differ from the original float inputs by up to 0.5. This introduces an inherent
    // +-2 LSB error between a correct fixed-point implementation using integer inputs
    // and the golden values. The testbench accepts outputs within +-2 of each golden value.
    for (i = 0; i < N; i = i + 1) begin
      // Check real part
      if ($signed(data_real_out[i] - golden_real[i]) >= -2 && $signed(data_real_out[i] - golden_real[i]) <= 2)
        $display("[PASS] Test %0d real: expected %0d, got %0d", i, golden_real[i], data_real_out[i]);
      else begin
        $display("[FAIL] Test %0d real: expected %0d, got %0d", i, golden_real[i], data_real_out[i]);
        fail_count = fail_count + 1;
      end
      pass_count = pass_count + ($signed(data_real_out[i] - golden_real[i]) >= -2 && $signed(data_real_out[i] - golden_real[i]) <= 2 ? 1 : 0);

      // Check imaginary part
      if ($signed(data_imag_out[i] - golden_imag[i]) >= -2 && $signed(data_imag_out[i] - golden_imag[i]) <= 2)
        $display("[PASS] Test %0d imag: expected %0d, got %0d", i, golden_imag[i], data_imag_out[i]);
      else begin
        $display("[FAIL] Test %0d imag: expected %0d, got %0d", i, golden_imag[i], data_imag_out[i]);
        fail_count = fail_count + 1;
      end
      pass_count = pass_count + ($signed(data_imag_out[i] - golden_imag[i]) >= -2 && $signed(data_imag_out[i] - golden_imag[i]) <= 2 ? 1 : 0);
    end

    // Summary (2*N total checks: N real + N imag)
    if (fail_count == 0)
      $display("[PASS] All %0d/%0d tests passed", pass_count, 2*N);
    else
      $display("[FAIL] %0d/%0d tests passed", pass_count, 2*N);
    $finish;
  end
endmodule
