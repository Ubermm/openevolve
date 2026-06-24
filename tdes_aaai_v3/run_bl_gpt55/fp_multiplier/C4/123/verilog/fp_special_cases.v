`timescale 1ns/1ps

module fp_special_cases #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH
)(
    input  sign_a,
    input  sign_b,
    input  a_is_zero,
    input  a_is_inf,
    input  a_is_nan,
    input  b_is_zero,
    input  b_is_inf,
    input  b_is_nan,
    output reg special_valid,
    output reg [WIDTH-1:0] special_result,
    output reg [2:0] special_flags
);

    localparam [EXP_WIDTH-1:0]  EXP_ZERO     = {EXP_WIDTH{1'b0}};
    localparam [EXP_WIDTH-1:0]  EXP_ALL_ONES = {EXP_WIDTH{1'b1}};
    localparam [MANT_WIDTH-1:0] MANT_ZERO    = {MANT_WIDTH{1'b0}};
    localparam [MANT_WIDTH-1:0] QNAN_MANT    = {1'b1, {(MANT_WIDTH-1){1'b0}}};

    localparam [2:0] FLAG_NONE    = 3'b000;
    localparam [2:0] FLAG_INVALID = 3'b001;

    wire result_sign;
    wire any_nan;
    wire inf_times_zero;

    assign result_sign    = sign_a ^ sign_b;
    assign any_nan        = a_is_nan | b_is_nan;
    assign inf_times_zero = (a_is_inf & b_is_zero) | (b_is_inf & a_is_zero);

    always @* begin
        special_valid  = 1'b0;
        special_result = {WIDTH{1'b0}};
        special_flags  = FLAG_NONE;

        if (inf_times_zero) begin
            special_valid  = 1'b1;
            special_result = {1'b0, EXP_ALL_ONES, QNAN_MANT};
            special_flags  = FLAG_INVALID;
        end else if (any_nan) begin
            special_valid  = 1'b1;
            special_result = {1'b0, EXP_ALL_ONES, QNAN_MANT};
            special_flags  = FLAG_INVALID;
        end else if (a_is_inf | b_is_inf) begin
            special_valid  = 1'b1;
            special_result = {result_sign, EXP_ALL_ONES, MANT_ZERO};
            special_flags  = FLAG_NONE;
        end else if (a_is_zero | b_is_zero) begin
            special_valid  = 1'b1;
            special_result = {result_sign, EXP_ZERO, MANT_ZERO};
            special_flags  = FLAG_NONE;
        end
    end

endmodule