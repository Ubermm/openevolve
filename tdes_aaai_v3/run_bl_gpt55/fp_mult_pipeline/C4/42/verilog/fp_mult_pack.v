`timescale 1ns/1ps

module fp_mult_pack (
    input sign,
    input special_valid,
    input [31:0] special_result,
    input [23:0] mant_round,
    input signed [10:0] exp_round,
    output [31:0] result
);

    localparam signed [10:0] EXP_UNDERFLOW = 11'sd0;
    localparam signed [10:0] EXP_OVERFLOW  = 11'sd255;

    assign result =
        special_valid ? special_result :
        (exp_round >= EXP_OVERFLOW) ? {sign, 8'hFF, 23'b0} :
        (exp_round <= EXP_UNDERFLOW) ? {sign, 31'b0} :
        {sign, exp_round[7:0], mant_round[22:0]};

endmodule