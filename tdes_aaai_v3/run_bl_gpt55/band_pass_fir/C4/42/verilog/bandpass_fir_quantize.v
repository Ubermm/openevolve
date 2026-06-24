`timescale 1ns/1ps

module bandpass_fir_quantize #(
    parameter ACC_W      = 64,
    parameter OUT_W      = 24,
    parameter SHIFT_BITS = 15
) (
    input  signed [ACC_W-1:0] acc_in,
    output signed [OUT_W-1:0] data_out
);

    assign data_out = acc_in >>> SHIFT_BITS;

endmodule