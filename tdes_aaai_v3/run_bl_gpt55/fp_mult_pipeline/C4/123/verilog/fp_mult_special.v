module fp_mult_special (
    input        sign,
    input        a_zero,
    input        b_zero,
    input        a_inf,
    input        b_inf,
    input        a_nan,
    input        b_nan,
    output       is_special,
    output [31:0] special_result
);

    wire any_nan;
    wire any_inf;
    wire any_zero;
    wire invalid_zero_inf;

    assign any_nan          = a_nan | b_nan;
    assign any_inf          = a_inf | b_inf;
    assign any_zero         = a_zero | b_zero;
    assign invalid_zero_inf = (a_zero & b_inf) | (a_inf & b_zero);

    assign is_special = any_nan | invalid_zero_inf | any_inf | any_zero;

    assign special_result =
        (any_nan | invalid_zero_inf) ? 32'h7fc00000 :
        any_inf                     ? {sign, 8'hff, 23'h000000} :
        any_zero                    ? {sign, 31'h00000000} :
                                      32'h00000000;

endmodule