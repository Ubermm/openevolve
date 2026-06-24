module fp_mult_pack (
    input        sign,
    input [23:0] mant,
    input [7:0]  exp,
    input        overflow,
    input        underflow,
    input        is_special,
    input [31:0] special_result,
    output [31:0] result
);

    assign result = is_special ? special_result :
                    overflow   ? {sign, 8'hFF, 23'b0} :
                    underflow  ? {sign, 31'b0} :
                                 {sign, exp, mant[22:0]};

endmodule