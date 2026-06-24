`timescale 1ns/1ps

module fp_round_pack (
    input        sign,
    input  [8:0]  exp_norm,
    input  [26:0] sig_norm,
    input        is_zero,
    output [31:0] result
);

assign result = 32'd0;

endmodule