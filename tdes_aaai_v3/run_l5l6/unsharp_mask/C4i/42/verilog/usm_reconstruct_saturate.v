`timescale 1ns/1ps

module usm_reconstruct_saturate #(
    parameter PIXEL_W  = 8,
    parameter SCALED_W = 18
) (
    input  [PIXEL_W-1:0]          orig,
    input  signed [SCALED_W-1:0]  scaled,
    output [PIXEL_W-1:0]          pixel_out
);

    /*
     * Use one extra signed bit beyond the larger operand width.
     * This safely represents:
     *   - unsigned orig extended as a positive signed value
     *   - signed scaled value
     *   - their sum without overflowing the accumulator
     */
    localparam ACC_W = ((SCALED_W > PIXEL_W) ? SCALED_W : PIXEL_W) + 1;

    wire signed [ACC_W-1:0] orig_ext;
    wire signed [ACC_W-1:0] scaled_ext;
    wire signed [ACC_W-1:0] sum;
    wire signed [ACC_W-1:0] max_ext;

    assign orig_ext = $signed({
        {(ACC_W-PIXEL_W){1'b0}},
        orig
    });

    assign scaled_ext = {
        {(ACC_W-SCALED_W){scaled[SCALED_W-1]}},
        scaled
    };

    assign sum = orig_ext + scaled_ext;

    assign max_ext = $signed({
        {(ACC_W-PIXEL_W){1'b0}},
        {PIXEL_W{1'b1}}
    });

    assign pixel_out = (sum <= 0)       ? {PIXEL_W{1'b0}} :
                       (sum >= max_ext) ? {PIXEL_W{1'b1}} :
                                          sum[PIXEL_W-1:0];

endmodule