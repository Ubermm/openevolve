`timescale 1ns/1ps

module highpass_fir_quantize #(
    parameter ACC_W = 64,
    parameter OUT_W = 24,
    parameter SHIFT = 15
) (
    input  signed [ACC_W-1:0]  acc_in,
    output signed [OUT_W-1:0]  data_out
);

    wire signed [ACC_W-1:0] shifted_acc;

    assign shifted_acc = acc_in >>> SHIFT;
    assign data_out    = shifted_acc[OUT_W-1:0];

endmodule