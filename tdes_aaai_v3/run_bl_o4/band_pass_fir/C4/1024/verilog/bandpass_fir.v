`timescale 1ns/1ps
module bandpass_fir #(
  parameter DATA_W  = 20,
  parameter TAP_CNT = 101,
  parameter GAIN_W  = 4
)(
  input                       clk,
  input                       rst,
  input                       valid_in,
  input      [DATA_W-1:0]     data_in,
  output                      valid_out,
  output     [DATA_W+GAIN_W-1:0] data_out
);
  // Local parameters
  localparam COEFF_W = 16;
  localparam ACC_W   = 64;
  localparam OUT_W   = DATA_W + GAIN_W;

  // Sample delay line
  reg signed [DATA_W-1:0] sample_delay [0:TAP_CNT-1];
  // Accumulator pipeline
  reg signed [ACC_W-1:0]  acc_reg       [0:TAP_CNT-1];
  // Valid pipeline
  reg                     valid_pipe    [0:TAP_CNT];

  // Coefficient array (combinational)
  wire signed [COEFF_W-1:0] coeff_array [0:TAP_CNT-1];
  genvar gi;
  generate
    for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : GEN_COEFF
      coeff_mem #(.TAP_CNT(TAP_CNT)) coeff_i (
        .addr  (gi),
        .coeff (coeff_array[gi])
      );
    end
  endgenerate

  // MAC-next wires
  wire signed [ACC_W-1:0] acc_next [0:TAP_CNT-1];
  generate
    for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : GEN_MAC
      if (gi == 0) begin
        mac_unit #(
          .DATA_W  (DATA_W),
          .COEFF_W (COEFF_W),
          .ACC_W   (ACC_W)
        ) mac0 (
          .acc_in  ({ACC_W{1'b0}}),
          .sample  (sample_delay[0]),
          .coeff   (coeff_array[0]),
          .acc_out (acc_next[0])
        );
      end else begin
        mac_unit #(
          .DATA_W  (DATA_W),
          .COEFF_W (COEFF_W),
          .ACC_W   (ACC_W)
        ) macN (
          .acc_in  (acc_reg[gi-1]),
          .sample  (sample_delay[gi]),
          .coeff   (coeff_array[gi]),
          .acc_out (acc_next[gi])
        );
      end
    end
  endgenerate

  // Final rounding
  wire signed [OUT_W-1:0] round_out;
  round_shift #(
    .ACC_W (ACC_W),
    .SHIFT (DATA_W),
    .OUT_W (OUT_W)
  ) round_i (
    .acc_in   (acc_reg[TAP_CNT-1]),
    .data_out (round_out)
  );

  // Pipeline registers
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < TAP_CNT; i = i + 1) begin
        sample_delay[i] <= {DATA_W{1'b0}};
        acc_reg[i]      <= {ACC_W{1'b0}};
      end
      for (i = 0; i <= TAP_CNT; i = i + 1)
        valid_pipe[i]   <= 1'b0;
    end else begin
      // Shift sample delays
      sample_delay[0] <= data_in;
      for (i = 1; i < TAP_CNT; i = i + 1)
        sample_delay[i] <= sample_delay[i-1];
      // Update MAC registers
      for (i = 0; i < TAP_CNT; i = i + 1)
        acc_reg[i] <= acc_next[i];
      // Shift valid
      valid_pipe[0] <= valid_in;
      for (i = 1; i <= TAP_CNT; i = i + 1)
        valid_pipe[i] <= valid_pipe[i-1];
    end
  end

  assign valid_out = valid_pipe[TAP_CNT];
  assign data_out  = round_out;

endmodule