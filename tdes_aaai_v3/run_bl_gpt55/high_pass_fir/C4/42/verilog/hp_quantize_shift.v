`timescale 1ns/1ps

module hp_quantize_shift #(
    parameter ACC_W  = 64,
    parameter DATA_W = 20,
    parameter GAIN_W = 4,
    parameter OUT_W  = DATA_W + GAIN_W,
    parameter SHIFT  = 15
) (
    input  signed [ACC_W-1:0] acc,
    output signed [OUT_W-1:0] data_out
);

    wire signed [ACC_W-1:0] shifted_acc;

    assign shifted_acc = acc >>> SHIFT;
    assign data_out    = shifted_acc[OUT_W-1:0];

endmodule