`timescale 1ns/1ps

module usm_gain_scale #(
    parameter PIXEL_W = 8,
    parameter GAIN_W  = 8
) (
    input  signed [PIXEL_W:0] diff,
    input         [GAIN_W-1:0] gain,
    output signed [PIXEL_W+GAIN_W+1:0] scaled
);

    localparam DIFF_W = PIXEL_W + 1;
    localparam OUT_W  = PIXEL_W + GAIN_W + 2;

    wire signed [OUT_W-1:0] diff_ext;
    wire signed [OUT_W-1:0] gain_ext;

    assign diff_ext = {{(OUT_W-DIFF_W){diff[DIFF_W-1]}}, diff};
    assign gain_ext = {{(OUT_W-GAIN_W){1'b0}}, gain};

    assign scaled = diff_ext * gain_ext;

endmodule