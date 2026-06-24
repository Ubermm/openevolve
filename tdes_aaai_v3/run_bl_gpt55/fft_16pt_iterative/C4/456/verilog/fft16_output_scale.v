`timescale 1ns/1ps

module fft16_output_scale #(
    parameter DATA_W = 12,
    parameter GAIN_W = 4
) (
    input mode,
    input signed [DATA_W+GAIN_W-1:0] din,
    output signed [DATA_W+GAIN_W-1:0] dout
);

    localparam OUT_W = DATA_W + GAIN_W;

    assign dout = mode ? (din >>> GAIN_W) : din;

endmodule