`timescale 1ns/1ps

module floating_point_multiplier #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH,
    parameter EXP_CALC_WIDTH = EXP_WIDTH + MANT_WIDTH + 4
)(
    input clk,
    input rst,
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] b,
    input [2:0] rnd_mode,
    output reg [WIDTH-1:0] product,
    output reg [2:0] exception_flags
);

    wire sign_a;
    wire sign_b;
    wire [EXP_WIDTH-1:0] exp_a;
    wire [EXP_WIDTH-1:0] exp_b;
    wire [MANT_WIDTH-1:0] frac_a;
    wire [MANT_WIDTH-1:0] frac_b;
    wire [MANT_WIDTH:0] sig_a;
    wire [MANT_WIDTH:0] sig_b;
    wire signed [EXP_CALC_WIDTH-1:0] unbiased_exp_a;
    wire signed [EXP_CALC_WIDTH-1:0] unbiased_exp_b;
    wire is_zero_a;
    wire is_zero_b;
    wire is_subnormal_a;
    wire is_subnormal_b;
    wire is_inf_a;
    wire is_inf_b;
    wire is_nan_a;
    wire is_nan_b;

    wire special_valid;
    wire [WIDTH-1:0] special_product;
    wire [2:0] special_flags;

    wire core_sign;
    wire signed [EXP_CALC_WIDTH-1:0] core_exp_sum;
    wire [2*(MANT_WIDTH+1)-1:0] core_sig_product;

    wire [WIDTH-1:0] normal_product;
    wire [2:0] normal_flags;

    fp_mul_unpack #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH),
        .EXP_CALC_WIDTH(EXP_CALC_WIDTH)
    ) unpack_a (
        .operand(a),
        .sign(sign_a),
        .exp(exp_a),
        .frac(frac_a),
        .sig(sig_a),
        .unbiased_exp(unbiased_exp_a),
        .is_zero(is_zero_a),
        .is_subnormal(is_subnormal_a),
        .is_inf(is_inf_a),
        .is_nan(is_nan_a)
    );

    fp_mul_unpack #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH),
        .EXP_CALC_WIDTH(EXP_CALC_WIDTH)
    ) unpack_b (
        .operand(b),
        .sign(sign_b),
        .exp(exp_b),
        .frac(frac_b),
        .sig(sig_b),
        .unbiased_exp(unbiased_exp_b),
        .is_zero(is_zero_b),
        .is_subnormal(is_subnormal_b),
        .is_inf(is_inf_b),
        .is_nan(is_nan_b)
    );

    fp_mul_special_cases #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH)
    ) special_cases (
        .sign_a(sign_a),
        .sign_b(sign_b),
        .is_zero_a(is_zero_a),
        .is_zero_b(is_zero_b),
        .is_inf_a(is_inf_a),
        .is_inf_b(is_inf_b),
        .is_nan_a(is_nan_a),
        .is_nan_b(is_nan_b),
        .special_valid(special_valid),
        .special_product(special_product),
        .special_flags(special_flags)
    );

    fp_mul_core #(
        .MANT_WIDTH(MANT_WIDTH),
        .EXP_CALC_WIDTH(EXP_CALC_WIDTH)
    ) core (
        .sign_a(sign_a),
        .sign_b(sign_b),
        .sig_a(sig_a),
        .sig_b(sig_b),
        .unbiased_exp_a(unbiased_exp_a),
        .unbiased_exp_b(unbiased_exp_b),
        .result_sign(core_sign),
        .exp_sum(core_exp_sum),
        .sig_product(core_sig_product)
    );

    fp_mul_normalize_round #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH),
        .EXP_CALC_WIDTH(EXP_CALC_WIDTH)
    ) normalize_round (
        .result_sign(core_sign),
        .exp_sum(core_exp_sum),
        .sig_product(core_sig_product),
        .rnd_mode(rnd_mode),
        .product(normal_product),
        .exception_flags(normal_flags)
    );

    always @* begin
        if (rst) begin
            product = {WIDTH{1'b0}};
            exception_flags = 3'b000;
        end else if (special_valid) begin
            product = special_product;
            exception_flags = special_flags;
        end else begin
            product = normal_product;
            exception_flags = normal_flags;
        end
    end

endmodule