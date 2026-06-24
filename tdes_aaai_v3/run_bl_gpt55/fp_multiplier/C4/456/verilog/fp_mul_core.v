`timescale 1ns/1ps

module fp_mul_core #(
    parameter MANT_WIDTH     = 23,
    parameter EXP_CALC_WIDTH = 35
)(
    input  wire                              sign_a,
    input  wire                              sign_b,
    input  wire [MANT_WIDTH:0]              sig_a,
    input  wire [MANT_WIDTH:0]              sig_b,
    input  wire signed [EXP_CALC_WIDTH-1:0] unbiased_exp_a,
    input  wire signed [EXP_CALC_WIDTH-1:0] unbiased_exp_b,
    output wire                              result_sign,
    output wire signed [EXP_CALC_WIDTH:0]   exp_sum,
    output wire [2*(MANT_WIDTH+1)-1:0]      sig_product
);

    localparam SIG_WIDTH = MANT_WIDTH + 1;

    wire signed [EXP_CALC_WIDTH:0] unbiased_exp_a_ext;
    wire signed [EXP_CALC_WIDTH:0] unbiased_exp_b_ext;

    assign result_sign = sign_a ^ sign_b;

    assign unbiased_exp_a_ext = {unbiased_exp_a[EXP_CALC_WIDTH-1], unbiased_exp_a};
    assign unbiased_exp_b_ext = {unbiased_exp_b[EXP_CALC_WIDTH-1], unbiased_exp_b};

    assign exp_sum = unbiased_exp_a_ext + unbiased_exp_b_ext;

    assign sig_product = sig_a * sig_b;

endmodule