`timescale 1ns/1ps

module floating_point_multiplier #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH
)(
    input                  clk,
    input                  rst,
    input  [WIDTH-1:0]     a,
    input  [WIDTH-1:0]     b,
    input  [2:0]           rnd_mode,
    output reg [WIDTH-1:0] product,
    output reg [2:0]       exception_flags
);

    localparam SIG_WIDTH = MANT_WIDTH + 1;
    localparam EXP_CALC_WIDTH = EXP_WIDTH + 5;

    wire sign_a;
    wire [EXP_WIDTH-1:0] exp_a;
    wire [MANT_WIDTH-1:0] frac_a;
    wire [SIG_WIDTH-1:0] sig_a;
    wire signed [EXP_CALC_WIDTH-1:0] exp_unbiased_a;
    wire is_zero_a;
    wire is_subnormal_a;
    wire is_inf_a;
    wire is_nan_a;

    wire sign_b;
    wire [EXP_WIDTH-1:0] exp_b;
    wire [MANT_WIDTH-1:0] frac_b;
    wire [SIG_WIDTH-1:0] sig_b;
    wire signed [EXP_CALC_WIDTH-1:0] exp_unbiased_b;
    wire is_zero_b;
    wire is_subnormal_b;
    wire is_inf_b;
    wire is_nan_b;

    wire special_valid;
    wire [WIDTH-1:0] special_product;
    wire [2:0] special_flags;

    wire normal_sign;
    wire signed [EXP_CALC_WIDTH-1:0] normal_exp_unbiased;
    wire [SIG_WIDTH-1:0] normal_sig;
    wire normal_guard;
    wire normal_round_bit;
    wire normal_sticky;
    wire normal_zero_product;

    wire [WIDTH-1:0] normal_product;
    wire [2:0] normal_flags;

    fpm_unpack #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH)
    ) unpack_a (
        .operand(a),
        .sign(sign_a),
        .exp(exp_a),
        .frac(frac_a),
        .sig(sig_a),
        .exp_unbiased(exp_unbiased_a),
        .is_zero(is_zero_a),
        .is_subnormal(is_subnormal_a),
        .is_inf(is_inf_a),
        .is_nan(is_nan_a)
    );

    fpm_unpack #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH)
    ) unpack_b (
        .operand(b),
        .sign(sign_b),
        .exp(exp_b),
        .frac(frac_b),
        .sig(sig_b),
        .exp_unbiased(exp_unbiased_b),
        .is_zero(is_zero_b),
        .is_subnormal(is_subnormal_b),
        .is_inf(is_inf_b),
        .is_nan(is_nan_b)
    );

    fpm_special_cases #(
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

    fpm_mul_normalize #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH)
    ) mul_normalize (
        .sign_a(sign_a),
        .sign_b(sign_b),
        .sig_a(sig_a),
        .sig_b(sig_b),
        .exp_unbiased_a(exp_unbiased_a),
        .exp_unbiased_b(exp_unbiased_b),
        .result_sign(normal_sign),
        .result_exp_unbiased(normal_exp_unbiased),
        .result_sig(normal_sig),
        .guard_bit(normal_guard),
        .round_bit(normal_round_bit),
        .sticky_bit(normal_sticky),
        .zero_product(normal_zero_product)
    );

    fpm_round_pack #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH)
    ) round_pack (
        .sign(normal_sign),
        .exp_unbiased(normal_exp_unbiased),
        .sig(normal_sig),
        .guard_bit(normal_guard),
        .round_bit(normal_round_bit),
        .sticky_bit(normal_sticky),
        .zero_product(normal_zero_product),
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