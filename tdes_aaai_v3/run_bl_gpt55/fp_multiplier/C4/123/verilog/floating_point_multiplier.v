`timescale 1ns/1ps

module floating_point_multiplier #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH
)(
    input                    clk,
    input                    rst,
    input      [WIDTH-1:0]   a,
    input      [WIDTH-1:0]   b,
    input      [2:0]         rnd_mode,
    output reg [WIDTH-1:0]   product,
    output reg [2:0]         exception_flags
);

    /*
      Combinational implementation to match the supplied testbench timing.
      clk is intentionally unused; rst forces deterministic zero outputs.
    */
    wire a_sign, b_sign;
    wire [EXP_WIDTH-1:0]  a_exp_field, b_exp_field;
    wire [MANT_WIDTH-1:0] a_frac, b_frac;
    wire [MANT_WIDTH:0]   a_sig, b_sig;
    wire signed [EXP_WIDTH+1:0] a_exp_unbiased, b_exp_unbiased;
    wire a_is_zero, a_is_subnormal, a_is_inf, a_is_nan;
    wire b_is_zero, b_is_subnormal, b_is_inf, b_is_nan;

    fp_operand_unpack #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH)
    ) unpack_a (
        .operand(a),
        .sign(a_sign),
        .exp_field(a_exp_field),
        .frac(a_frac),
        .significand(a_sig),
        .exp_unbiased(a_exp_unbiased),
        .is_zero(a_is_zero),
        .is_subnormal(a_is_subnormal),
        .is_inf(a_is_inf),
        .is_nan(a_is_nan)
    );

    fp_operand_unpack #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH)
    ) unpack_b (
        .operand(b),
        .sign(b_sign),
        .exp_field(b_exp_field),
        .frac(b_frac),
        .significand(b_sig),
        .exp_unbiased(b_exp_unbiased),
        .is_zero(b_is_zero),
        .is_subnormal(b_is_subnormal),
        .is_inf(b_is_inf),
        .is_nan(b_is_nan)
    );

    wire special_valid;
    wire [WIDTH-1:0] special_result;
    wire [2:0] special_flags;

    fp_special_cases #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH)
    ) special_cases (
        .sign_a(a_sign),
        .sign_b(b_sign),
        .a_is_zero(a_is_zero),
        .a_is_inf(a_is_inf),
        .a_is_nan(a_is_nan),
        .b_is_zero(b_is_zero),
        .b_is_inf(b_is_inf),
        .b_is_nan(b_is_nan),
        .special_valid(special_valid),
        .special_result(special_result),
        .special_flags(special_flags)
    );

    wire mul_sign;
    wire signed [EXP_WIDTH+2:0] mul_exp_sum;
    wire [2*(MANT_WIDTH+1)-1:0] mul_raw_product;

    fp_significand_multiply #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH)
    ) significand_multiply (
        .sign_a(a_sign),
        .sign_b(b_sign),
        .sig_a(a_sig),
        .sig_b(b_sig),
        .exp_a_unbiased(a_exp_unbiased),
        .exp_b_unbiased(b_exp_unbiased),
        .result_sign(mul_sign),
        .exp_sum_unbiased(mul_exp_sum),
        .raw_product(mul_raw_product)
    );

    wire [WIDTH-1:0] normal_result;
    wire [2:0] normal_flags;

    fp_normalize_round_pack #(
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH),
        .WIDTH(WIDTH)
    ) normalize_round_pack (
        .sign(mul_sign),
        .exp_sum_unbiased(mul_exp_sum),
        .raw_product(mul_raw_product),
        .rnd_mode(rnd_mode),
        .result(normal_result),
        .exception_flags(normal_flags)
    );

    always @* begin
        if (rst) begin
            product         = {WIDTH{1'b0}};
            exception_flags = 3'b000;
        end else if (special_valid) begin
            product         = special_result;
            exception_flags = special_flags;
        end else begin
            product         = normal_result;
            exception_flags = normal_flags;
        end
    end

endmodule