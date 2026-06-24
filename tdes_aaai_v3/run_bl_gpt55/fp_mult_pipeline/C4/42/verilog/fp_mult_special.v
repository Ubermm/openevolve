`timescale 1ns/1ps

module fp_mult_special (
    input sign,
    input a_zero,
    input a_inf,
    input a_nan,
    input b_zero,
    input b_inf,
    input b_nan,
    output special_valid,
    output [31:0] special_result
);

    wire any_nan;
    wire invalid_zero_inf;
    wire any_inf;
    wire any_zero;

    assign any_nan          = a_nan | b_nan;
    assign invalid_zero_inf = (a_zero & b_inf) | (a_inf & b_zero);
    assign any_inf          = a_inf | b_inf;
    assign any_zero         = a_zero | b_zero;

    assign special_valid = any_nan | invalid_zero_inf | any_inf | any_zero;

    assign special_result =
        (any_nan | invalid_zero_inf) ? 32'h7fc00000 :
        any_inf                     ? {sign, 8'hff, 23'b0} :
        any_zero                    ? {sign, 31'b0} :
                                      32'b0;

endmodule