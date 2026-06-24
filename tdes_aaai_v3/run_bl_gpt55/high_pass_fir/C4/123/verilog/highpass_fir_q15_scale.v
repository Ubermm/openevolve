`timescale 1ns/1ps

module highpass_fir_q15_scale #(
    parameter DATA_W = 20,
    parameter GAIN_W = 4,
    parameter SHIFT  = 20
) (
    input  signed [63:0]                  acc_in,
    output signed [DATA_W+GAIN_W-1:0]     data_out
);

    localparam OUT_W = DATA_W + GAIN_W;

    wire signed [63:0] scaled;

    assign scaled   = acc_in >>> SHIFT;
    assign data_out = scaled[OUT_W-1:0];

endmodule