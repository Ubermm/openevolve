`timescale 1ns/1ps

module usm_highpass #(
    parameter PIXEL_W = 8
) (
    input  [PIXEL_W-1:0] orig,
    input  [PIXEL_W-1:0] blur,
    output signed [PIXEL_W:0] diff
);

    wire signed [PIXEL_W:0] orig_ext;
    wire signed [PIXEL_W:0] blur_ext;

    assign orig_ext = $signed({1'b0, orig});
    assign blur_ext = $signed({1'b0, blur});

    assign diff = orig_ext - blur_ext;

endmodule