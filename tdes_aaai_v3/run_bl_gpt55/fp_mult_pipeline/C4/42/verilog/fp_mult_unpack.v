`timescale 1ns/1ps

module fp_mult_unpack (
    input  [31:0] op,
    output        sign,
    output [7:0]  exp,
    output [22:0] frac,
    output [23:0] mant,
    output [8:0]  exp_eff,
    output        is_zero,
    output        is_inf,
    output        is_nan
);

    assign sign = op[31];
    assign exp  = op[30:23];
    assign frac = op[22:0];

    assign is_zero = (exp == 8'h00) && (frac == 23'h000000);
    assign is_inf  = (exp == 8'hff) && (frac == 23'h000000);
    assign is_nan  = (exp == 8'hff) && (frac != 23'h000000);

    assign mant = (exp == 8'h00) ? {1'b0, frac} : {1'b1, frac};

    assign exp_eff = is_zero ? 9'd0 :
                     (exp == 8'h00) ? 9'd1 :
                     {1'b0, exp};

endmodule