module round_shift #(
  parameter ACC_W  = 64,
  parameter SHIFT  = 20,
  parameter OUT_W  = 24
)(
  input  signed [ACC_W-1:0] acc_in,
  output signed [OUT_W-1:0] data_out
);
  // Round-to-nearest, tie-away-from-zero for a 2^SHIFT denominator
  // Compute bias = 2^(SHIFT-1)
  localparam signed [ACC_W-1:0] BIAS = ({{ACC_W{1'b0}}} + 1) << (SHIFT-1);
  // Select +BIAS for non-negative inputs, -BIAS for negative inputs
  wire signed [ACC_W-1:0] bias_val   = acc_in[ACC_W-1] ? -BIAS : BIAS;
  // Add bias then truncate (arithmetic right shift)
  wire signed [ACC_W-1:0] acc_biased = acc_in + bias_val;
  assign data_out = acc_biased[SHIFT + OUT_W - 1 : SHIFT];
endmodule