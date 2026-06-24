module fp_add_sub(
  // Aligned significands (including implicit leading 1 and any guard bits)
  input  [23:0] mant_a,
  input  [23:0] mant_b,
  // Signs of the original operands
  input         sign_a,
  input         sign_b,
  // Operation: 0 = add, 1 = subtract
  input         add_sub,
  // Raw sum/difference (one bit wider than inputs for carry/borrow)
  output [24:0] sum,
  // Sign of the result
  output        sign_out
);

  // If subtraction, flip B's sign
  wire sign_b_eff = sign_b ^ add_sub;

  // If signs match after possible flip, perform addition; otherwise subtraction
  wire do_add = (sign_a == sign_b_eff);

  // Extend operands by one MSB to accommodate carry/borrow
  wire [24:0] op_a = {1'b0, mant_a};
  wire [24:0] op_b = {1'b0, mant_b};

  // Compute both add and subtract results
  wire [24:0] sum_add = op_a + op_b;
  wire [24:0] diff_ab = op_a - op_b;
  wire [24:0] diff_ba = op_b - op_a;

  // Select the correct result and sign
  assign sum = do_add
               ? sum_add
               : ((op_a >= op_b) ? diff_ab : diff_ba);

  assign sign_out = do_add
                    ? sign_a
                    : ((op_a >= op_b) ? sign_a : sign_b_eff);

endmodule