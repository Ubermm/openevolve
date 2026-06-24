`timescale 1ns/1ps

module fp_mult_mul_exp (
    input  [23:0] mant_a,
    input  [23:0] mant_b,
    input  [8:0]  exp_a_eff,
    input  [8:0]  exp_b_eff,
    output [47:0] product,
    output signed [10:0] exp_unrounded
);

    localparam signed [10:0] EXP_BIAS = 11'sd127;

    assign product = mant_a * mant_b;

    assign exp_unrounded =
        $signed({2'b00, exp_a_eff}) +
        $signed({2'b00, exp_b_eff}) -
        EXP_BIAS;

endmodule