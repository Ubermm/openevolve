module fp_round_pack(
    input         sign_in,
    input  [7:0]  exp_in,
    input  [25:0] mant_in,
    input         is_zero_a,
    input         is_zero_b,
    input         is_inf_a,
    input         is_inf_b,
    input         is_nan_a,
    input         is_nan_b,
    input         op,             // 0: add, 1: subtract
    input  [7:0]  exp_a,
    input  [7:0]  exp_b,
    input         sign_a,
    input         sign_b,
    output [31:0] result
);

    // Special‐case detection
    wire any_nan    = is_nan_a  | is_nan_b;
    wire any_inf    = is_inf_a  | is_inf_b;
    // Effective sign for B when doing subtraction
    wire sign_b_eff = sign_b ^ op;

    // Default quiet NaN
    wire [31:0] nan_result = {1'b0, 8'hFF, 1'b1, 22'b0};
    // Infinity representations
    wire [31:0] inf_a = {sign_a,    8'hFF, 23'b0};
    wire [31:0] inf_b = {sign_b_eff,8'hFF, 23'b0};
    // Inf−Inf with opposite signs → NaN
    wire inf_inf_to_nan = is_inf_a & is_inf_b & (sign_a != sign_b_eff);
    // Both operands zero → zero result
    wire both_zero = is_zero_a & is_zero_b;
    wire [31:0] zero_result = {sign_in, 8'b0, 23'b0};

    // Extract mantissa, guard and sticky bits
    // mant_in: [25] = carry after normalization, [24:1] = mantissa+guard, [0] = sticky
    wire [23:0] mant24 = mant_in[25] ? mant_in[25:2] : mant_in[24:1];
    wire        guard  = mant_in[1];
    wire        sticky = mant_in[0];

    // Round-to-even increment decision
    wire round_inc = guard & (sticky | mant24[0]);

    // Add the increment
    wire [24:0] mant_plus   = {1'b0, mant24} + round_inc;
    wire        carry_round = mant_plus[24];

    // Adjust exponent if carry out from rounding
    wire [8:0] exp_plus = {1'b0, exp_in} + carry_round;

    // Detect overflow (exponent >= 255)
    wire        overflow  = (exp_plus >= 9'd255);
    wire [7:0]  exp_final = overflow ? 8'hFF : exp_plus[7:0];

    // Final fraction bits after rounding
    wire [22:0] frac_final = overflow
                          ? 23'b0
                          : (carry_round ? mant_plus[23:1]
                                         : mant_plus[22:0]);

    // Normal (rounded) result
    wire [31:0] normal = {sign_in, exp_final, frac_final};

    // Priority select the final result
    // 1) Inf−Inf → NaN
    // 2) Any NaN
    // 3) Infinity A or B
    // 4) Both zero → zero
    // 5) Normal rounded result
    assign result = inf_inf_to_nan ? nan_result :
                    any_nan         ? nan_result :
                    is_inf_a        ? inf_a      :
                    is_inf_b        ? inf_b      :
                    both_zero       ? zero_result:
                                      normal;

endmodule