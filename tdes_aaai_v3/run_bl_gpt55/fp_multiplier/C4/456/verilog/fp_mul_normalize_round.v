`timescale 1ns/1ps

module fp_mul_normalize_round #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH,
    parameter EXP_CALC_WIDTH = EXP_WIDTH + MANT_WIDTH + 4
)(
    input result_sign,
    input signed [EXP_CALC_WIDTH-1:0] exp_sum,
    input [2*(MANT_WIDTH+1)-1:0] sig_product,
    input [2:0] rnd_mode,
    output reg [WIDTH-1:0] product,
    output reg [2:0] exception_flags
);

    always @* begin
        product = {WIDTH{1'b0}};
        exception_flags = 3'b000;
    end

endmodule