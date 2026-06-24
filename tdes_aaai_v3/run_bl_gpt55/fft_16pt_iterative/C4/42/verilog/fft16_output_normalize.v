module fft16_output_normalize #(
    parameter DATA_W = 12,
    parameter GAIN_W = 4
) (
    input  mode, // 0: FFT passthrough, 1: IFFT divide by 16
    input  signed [DATA_W+GAIN_W-1:0] din,
    output signed [DATA_W+GAIN_W-1:0] dout
);

    assign dout = mode ? (din >>> GAIN_W) : din;

endmodule