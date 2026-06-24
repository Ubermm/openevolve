`timescale 1ns/1ps

module conv1d_output_cast #(
    parameter ACC_W = 32,
    parameter OUT_W = 12
) (
    input  signed [ACC_W-1:0] acc_in,
    output        [OUT_W-1:0] data_out
);

    // Final output-width adaptation.
    // The convolution accumulator is wider than the exported output width.
    // Per specification, this stage truncates to OUT_W bits by keeping the
    // least-significant bits. No saturation, rounding, or registering is done.
    assign data_out = acc_in[OUT_W-1:0];

endmodule