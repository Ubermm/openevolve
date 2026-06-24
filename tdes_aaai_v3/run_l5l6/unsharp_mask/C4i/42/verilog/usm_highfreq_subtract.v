`timescale 1ns/1ps

module usm_highfreq_subtract #(
    parameter PIXEL_W = 8,
    parameter DIFF_W  = PIXEL_W + 1
) (
    input  [PIXEL_W-1:0]        orig,
    input  [PIXEL_W-1:0]        blurred,
    output signed [DIFF_W-1:0]  diff
);

    /*
     * Pixels are unsigned values.  Extend them with a leading zero before
     * treating them as signed operands, otherwise values with MSB=1 would be
     * interpreted as negative.
     *
     * With the default DIFF_W = PIXEL_W + 1, this exactly covers the full
     * difference range:
     *
     *   -(2^PIXEL_W - 1) through +(2^PIXEL_W - 1)
     */
    wire signed [DIFF_W-1:0] orig_ext;
    wire signed [DIFF_W-1:0] blur_ext;

    assign orig_ext = $signed({1'b0, orig});
    assign blur_ext = $signed({1'b0, blurred});

    assign diff = orig_ext - blur_ext;

endmodule