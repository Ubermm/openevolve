module fp_mult_mul_exp (
    input  [23:0] mant_a,
    input  [23:0] mant_b,
    input  signed [11:0] exp_a_eff,
    input  signed [11:0] exp_b_eff,
    output [47:0] product,
    output signed [11:0] exp_sum
);

    localparam signed [11:0] EXP_BIAS = 12'sd127;

    assign product = {24'b0, mant_a} * mant_b;
    assign exp_sum = exp_a_eff + exp_b_eff - EXP_BIAS;

endmodule