`timescale 1ns/1ps

module fp_special_cases (
    input        a_sign,
    input        b_sign,
    input        a_is_nan,
    input        b_is_nan,
    input        a_is_inf,
    input        b_is_inf,
    output       is_special,
    output [31:0] special_result
);

wire any_nan;
wire any_inf;
wire inf_cancel;
wire result_sign;

assign any_nan    = a_is_nan | b_is_nan;
assign any_inf    = a_is_inf | b_is_inf;
assign inf_cancel = a_is_inf & b_is_inf & (a_sign ^ b_sign);

assign is_special = any_nan | any_inf;

assign result_sign = a_is_inf ? a_sign : b_sign;

assign special_result =
    (any_nan | inf_cancel) ? 32'h7fc00000 :
    any_inf                ? {result_sign, 8'hff, 23'd0} :
                             32'd0;

endmodule