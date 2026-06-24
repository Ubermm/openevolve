`timescale 1ns/1ps

module fir_output_scaler #(
    parameter ACC_W      = 64,
    parameter OUT_W      = 24,
    parameter SHIFT_BITS = 20
) (
    input  signed [ACC_W-1:0] acc_in,
    output        [OUT_W-1:0] data_out
);

    wire signed [ACC_W-1:0] shifted_acc;

    assign shifted_acc = acc_in >>> SHIFT_BITS;
    assign data_out    = shifted_acc[OUT_W-1:0];

endmodule