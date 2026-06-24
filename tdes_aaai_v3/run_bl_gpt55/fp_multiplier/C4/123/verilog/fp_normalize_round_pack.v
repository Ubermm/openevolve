`timescale 1ns/1ps

module fp_normalize_round_pack #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH
)(
    input  sign,
    input  signed [EXP_WIDTH+2:0] exp_sum_unbiased,
    input  [2*(MANT_WIDTH+1)-1:0] raw_product,
    input  [2:0] rnd_mode,
    output reg [WIDTH-1:0] result,
    output reg [2:0] exception_flags
);

    always @* begin
        result          = {WIDTH{1'b0}};
        exception_flags = 3'b000;
    end

endmodule