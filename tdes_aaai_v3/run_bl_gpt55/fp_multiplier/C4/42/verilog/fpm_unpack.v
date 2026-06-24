`timescale 1ns/1ps

module fpm_unpack #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH
)(
    input  [WIDTH-1:0] operand,
    output reg sign,
    output reg [EXP_WIDTH-1:0] exp,
    output reg [MANT_WIDTH-1:0] frac,
    output reg [MANT_WIDTH:0] sig,
    output reg signed [EXP_WIDTH+4:0] exp_unbiased,
    output reg is_zero,
    output reg is_subnormal,
    output reg is_inf,
    output reg is_nan
);

    localparam integer EXP_BIAS = (1 << (EXP_WIDTH-1)) - 1;

    always @* begin
        sign = operand[WIDTH-1];
        exp  = operand[WIDTH-2:MANT_WIDTH];
        frac = operand[MANT_WIDTH-1:0];

        is_zero      = (exp == {EXP_WIDTH{1'b0}}) && (frac == {MANT_WIDTH{1'b0}});
        is_subnormal = (exp == {EXP_WIDTH{1'b0}}) && (frac != {MANT_WIDTH{1'b0}});
        is_inf       = (exp == {EXP_WIDTH{1'b1}}) && (frac == {MANT_WIDTH{1'b0}});
        is_nan       = (exp == {EXP_WIDTH{1'b1}}) && (frac != {MANT_WIDTH{1'b0}});

        if (exp == {EXP_WIDTH{1'b0}}) begin
            sig = {1'b0, frac};
            exp_unbiased = 1 - EXP_BIAS;
        end else begin
            sig = {1'b1, frac};
            exp_unbiased = $signed({{5{1'b0}}, exp}) - EXP_BIAS;
        end
    end

endmodule