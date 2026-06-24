`timescale 1ns/1ps

module fp_mul_unpack #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH,
    parameter EXP_CALC_WIDTH = EXP_WIDTH + MANT_WIDTH + 4
)(
    input  [WIDTH-1:0] operand,
    output reg sign,
    output reg [EXP_WIDTH-1:0] exp,
    output reg [MANT_WIDTH-1:0] frac,
    output reg [MANT_WIDTH:0] sig,
    output reg signed [EXP_CALC_WIDTH-1:0] unbiased_exp,
    output reg is_zero,
    output reg is_subnormal,
    output reg is_inf,
    output reg is_nan
);

    localparam [EXP_WIDTH-1:0] EXP_ZERO     = {EXP_WIDTH{1'b0}};
    localparam [EXP_WIDTH-1:0] EXP_ALL_ONES = {EXP_WIDTH{1'b1}};
    localparam [MANT_WIDTH-1:0] FRAC_ZERO   = {MANT_WIDTH{1'b0}};

    localparam signed [EXP_CALC_WIDTH-1:0] EXP_BIAS =
        $signed({{(EXP_CALC_WIDTH-EXP_WIDTH){1'b0}},
                 {1'b0, {(EXP_WIDTH-1){1'b1}}}});

    localparam signed [EXP_CALC_WIDTH-1:0] EXP_ONE =
        {{(EXP_CALC_WIDTH-1){1'b0}}, 1'b1};

    reg signed [EXP_CALC_WIDTH-1:0] exp_extended;

    always @* begin
        sign = operand[WIDTH-1];
        exp  = operand[WIDTH-2:MANT_WIDTH];
        frac = operand[MANT_WIDTH-1:0];

        is_zero      = (exp == EXP_ZERO)     && (frac == FRAC_ZERO);
        is_subnormal = (exp == EXP_ZERO)     && (frac != FRAC_ZERO);
        is_inf       = (exp == EXP_ALL_ONES) && (frac == FRAC_ZERO);
        is_nan       = (exp == EXP_ALL_ONES) && (frac != FRAC_ZERO);

        sig = (exp == EXP_ZERO) ? {1'b0, frac} : {1'b1, frac};

        exp_extended = $signed({{(EXP_CALC_WIDTH-EXP_WIDTH){1'b0}}, exp});

        if (exp == EXP_ZERO) begin
            unbiased_exp = EXP_ONE - EXP_BIAS;
        end else begin
            unbiased_exp = exp_extended - EXP_BIAS;
        end
    end

endmodule