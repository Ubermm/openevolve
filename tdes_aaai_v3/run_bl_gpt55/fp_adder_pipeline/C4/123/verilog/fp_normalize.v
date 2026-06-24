`timescale 1ns/1ps

module fp_normalize (
    input        sign_in,
    input  [7:0]  exp_in,
    input  [27:0] sig_sum,
    input        zero_in,
    output       sign_out,
    output [8:0] exp_out,
    output [26:0] sig_norm,
    output       zero_out
);

assign sign_out = 1'b0;
assign exp_out  = 9'd0;
assign sig_norm = 27'd0;
assign zero_out = 1'b0;

endmodule