`timescale 1ns/1ps

module fp_operand_unpack #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH
)(
    input      [WIDTH-1:0] operand,
    output reg             sign,
    output reg [EXP_WIDTH-1:0]  exp_field,
    output reg [MANT_WIDTH-1:0] frac,
    output reg [MANT_WIDTH:0]   significand,
    output reg signed [EXP_WIDTH+1:0] exp_unbiased,
    output reg             is_zero,
    output reg             is_subnormal,
    output reg             is_inf,
    output reg             is_nan
);

    localparam integer EXP_BIAS_INT = (1 << (EXP_WIDTH-1)) - 1;

    localparam [EXP_WIDTH-1:0]  EXP_ALL_ZERO  = {EXP_WIDTH{1'b0}};
    localparam [EXP_WIDTH-1:0]  EXP_ALL_ONES  = {EXP_WIDTH{1'b1}};
    localparam [MANT_WIDTH-1:0] FRAC_ALL_ZERO = {MANT_WIDTH{1'b0}};

    always @* begin
        sign      = operand[WIDTH-1];
        exp_field = operand[WIDTH-2:MANT_WIDTH];
        frac      = operand[MANT_WIDTH-1:0];

        is_zero      = (exp_field == EXP_ALL_ZERO) && (frac == FRAC_ALL_ZERO);
        is_subnormal = (exp_field == EXP_ALL_ZERO) && (frac != FRAC_ALL_ZERO);
        is_inf       = (exp_field == EXP_ALL_ONES) && (frac == FRAC_ALL_ZERO);
        is_nan       = (exp_field == EXP_ALL_ONES) && (frac != FRAC_ALL_ZERO);

        if (exp_field == EXP_ALL_ZERO) begin
            significand  = {1'b0, frac};
            exp_unbiased = 1 - EXP_BIAS_INT;
        end else begin
            significand  = {1'b1, frac};
            exp_unbiased = $signed({2'b00, exp_field}) - EXP_BIAS_INT;
        end
    end

endmodule