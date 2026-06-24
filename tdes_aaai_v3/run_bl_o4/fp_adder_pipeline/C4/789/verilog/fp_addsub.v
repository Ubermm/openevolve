module fp_addsub(
    input  [26:0] manA,      // Aligned significand A (including hidden bit + guard bits)
    input  [26:0] manB,      // Aligned significand B (including hidden bit + guard bits)
    input         signA,     // Sign of operand A
    input         signB,     // Sign of operand B
    input         add_sub,   // 0 = add, 1 = subtract (A - B)
    output [27:0] sum,       // Raw result significand (may have carry in bit[27])
    output        sum_sign,  // Sign of the result
    output        isZero     // High if result significand is zero
);

  // Compute effective sign of B depending on add_sub control
  wire signB_eff = signB ^ add_sub;

  // Determine whether to perform addition or subtraction on magnitudes
  wire do_add = (signA == signB_eff);

  // For subtraction of magnitudes, ensure the larger operand is op1
  wire magA_lt_magB = (manA < manB);
  wire [26:0] op1 = do_add ? manA : (magA_lt_magB ? manB : manA);
  wire [26:0] op2 = do_add ? manB : (magA_lt_magB ? manA : manB);

  // Determine sign of the result magnitude
  wire op1_sign = do_add ? signA : (magA_lt_magB ? signB_eff : signA);

  // Perform the add or subtract with one extra bit for carry/borrow
  wire [27:0] add_res = {1'b0, op1} + {1'b0, op2};
  wire [27:0] sub_res = {1'b0, op1} - {1'b0, op2};
  wire [27:0] raw    = do_add ? add_res : sub_res;
  wire        raw_s  = do_add ? signA    : op1_sign;

  // Zero detection: result is zero if all bits are zero
  wire zero = (raw == 28'b0);

  // Assign outputs
  assign sum      = raw;
  assign sum_sign = zero ? 1'b0 : raw_s;  // force +0 when result is zero
  assign isZero   = zero;

endmodule