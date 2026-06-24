module fp_round(
    input         sign_in,
    input  signed [9:0] exp_norm,
    input        [23:0] mant_norm,
    input               guard,
    input               round,
    input               sticky,
    input               is_zero_a,
    input               is_inf_a,
    input               is_nan_a,
    input               is_subnormal_a,
    input               is_zero_b,
    input               is_inf_b,
    input               is_nan_b,
    input               is_subnormal_b,
    output              sign_out,
    output signed [9:0] exp_round,
    output       [23:0] mant_round,
    output              is_zero_a_out,
    output              is_inf_a_out,
    output              is_nan_a_out,
    output              is_subnormal_a_out,
    output              is_zero_b_out,
    output              is_inf_b_out,
    output              is_nan_b_out,
    output              is_subnormal_b_out
);

    // Round-to-nearest-even increment decision
    wire round_inc = guard & (round | sticky | mant_norm[0]);

    // Sum mantissa + round increment (one extra MSB for overflow detection)
    wire [24:0] mant_sum = {1'b0, mant_norm} + round_inc;

    // Detect mantissa overflow (25th bit)
    wire        mant_oflow = mant_sum[24];

    // Shift mantissa and adjust exponent if mantissa overflows
    wire [23:0] mant_normed = mant_oflow ? mant_sum[24:1] : mant_sum[23:0];
    wire signed [9:0] exp_normed = mant_oflow ? (exp_norm + 10'sd1) : exp_norm;

    // Detect exponent overflow/underflow (IEEE-754 single: exp 1..254 normal)
    wire exp_overflow  = (exp_normed > 10'sd254);
    wire exp_underflow = (exp_normed < 10'sd1);

    // Clamp exponent & mantissa for overflow/underflow
    wire signed [9:0] exp_clamped = exp_overflow  ? 10'sd255 :
                                    exp_underflow ? 10'sd0   :
                                    exp_normed;
    wire [23:0] mant_clamped = (exp_overflow || exp_underflow) ? 24'b0
                                                               : mant_normed;

    // Outputs
    assign sign_out     = sign_in;
    assign exp_round    = exp_clamped;
    assign mant_round   = mant_clamped;

    // Pass through special-case flags for operands
    assign is_zero_a_out       = is_zero_a;
    assign is_inf_a_out        = is_inf_a;
    assign is_nan_a_out        = is_nan_a;
    assign is_subnormal_a_out  = is_subnormal_a;
    assign is_zero_b_out       = is_zero_b;
    assign is_inf_b_out        = is_inf_b;
    assign is_nan_b_out        = is_nan_b;
    assign is_subnormal_b_out  = is_subnormal_b;

endmodule