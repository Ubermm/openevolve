`timescale 1ns/1ps

module fpm_special_cases #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH
)(
    input  sign_a,
    input  sign_b,
    input  is_zero_a,
    input  is_zero_b,
    input  is_inf_a,
    input  is_inf_b,
    input  is_nan_a,
    input  is_nan_b,
    output reg special_valid,
    output reg [WIDTH-1:0] special_product,
    output reg [2:0] special_flags
);

    localparam [2:0] FLAG_NONE    = 3'b000;
    localparam [2:0] FLAG_INVALID = 3'b001;

    wire result_sign;
    wire invalid_mul;
    wire any_nan;

    reg [MANT_WIDTH-1:0] qnan_frac;

    assign result_sign = sign_a ^ sign_b;
    assign invalid_mul = (is_inf_a && is_zero_b) || (is_inf_b && is_zero_a);
    assign any_nan     = is_nan_a || is_nan_b;

    always @* begin
        qnan_frac = {MANT_WIDTH{1'b0}};
        qnan_frac[MANT_WIDTH-1] = 1'b1;
    end

    always @* begin
        special_valid   = 1'b0;
        special_product = {WIDTH{1'b0}};
        special_flags   = FLAG_NONE;

        if (invalid_mul) begin
            special_valid   = 1'b1;
            special_product = {1'b0, {EXP_WIDTH{1'b1}}, qnan_frac};
            special_flags   = FLAG_INVALID;
        end else if (any_nan) begin
            special_valid   = 1'b1;
            special_product = {1'b0, {EXP_WIDTH{1'b1}}, qnan_frac};
            special_flags   = FLAG_NONE;
        end else if (is_inf_a || is_inf_b) begin
            special_valid   = 1'b1;
            special_product = {result_sign, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}};
            special_flags   = FLAG_NONE;
        end else if (is_zero_a || is_zero_b) begin
            special_valid   = 1'b1;
            special_product = {result_sign, {EXP_WIDTH{1'b0}}, {MANT_WIDTH{1'b0}}};
            special_flags   = FLAG_NONE;
        end
    end

endmodule