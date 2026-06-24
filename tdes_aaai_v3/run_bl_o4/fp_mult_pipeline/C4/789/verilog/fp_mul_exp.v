module fp_mul_exp(
    input        sign_a,
    input  [7:0] exp_a,
    input [23:0] mant_a,
    input        is_zero_a,
    input        is_inf_a,
    input        is_nan_a,
    input        is_subnormal_a,
    input        sign_b,
    input  [7:0] exp_b,
    input [23:0] mant_b,
    input        is_zero_b,
    input        is_inf_b,
    input        is_nan_b,
    input        is_subnormal_b,
    output       sign_out,
    output signed [9:0] exp_sum,
    output [47:0]     mant_prod,
    output       is_zero_a_out,
    output       is_inf_a_out,
    output       is_nan_a_out,
    output       is_subnormal_a_out,
    output       is_zero_b_out,
    output       is_inf_b_out,
    output       is_nan_b_out,
    output       is_subnormal_b_out
);

    // sign of product
    assign sign_out = sign_a ^ sign_b;

    // determine if result is forced zero (one operand zero)
    wire zero_op = is_zero_a | is_zero_b;

    // true exponent (unbiased) for A and B:
    // normals: exp - 127; subnormals: true exponent = -126
    wire signed [8:0] exp_true_a = (exp_a != 8'd0)
                                   ? $signed({1'b0, exp_a}) - 9'sd127
                                   : -9'sd126;
    wire signed [8:0] exp_true_b = (exp_b != 8'd0)
                                   ? $signed({1'b0, exp_b}) - 9'sd127
                                   : -9'sd126;

    // sum of true exponents
    wire signed [9:0] raw_sum = exp_true_a + exp_true_b;
    // override to -127 for zero result so biased exponent becomes 0
    assign exp_sum = zero_op ? -10'sd127 : raw_sum;

    // 24×24→48-bit mantissa product (will be zero if either input mantissa is zero)
    assign mant_prod = mant_a * mant_b;

    // forward individual special‐case flags, but if zero_op then clear inf/nan/subnormal
    assign is_zero_a_out       = is_zero_a;
    assign is_zero_b_out       = is_zero_b;

    assign is_inf_a_out        = zero_op ? 1'b0 : is_inf_a;
    assign is_inf_b_out        = zero_op ? 1'b0 : is_inf_b;

    assign is_nan_a_out        = zero_op ? 1'b0 : is_nan_a;
    assign is_nan_b_out        = zero_op ? 1'b0 : is_nan_b;

    assign is_subnormal_a_out  = zero_op ? 1'b0 : is_subnormal_a;
    assign is_subnormal_b_out  = zero_op ? 1'b0 : is_subnormal_b;

endmodule