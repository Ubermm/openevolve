`timescale 1ns/1ps

module usm_gain_scale #(
    parameter DIFF_W   = 9,
    parameter GAIN_W   = 8,
    parameter SCALED_W = DIFF_W + GAIN_W + 1
) (
    input  signed [DIFF_W-1:0]   diff,
    input         [GAIN_W-1:0]   gain,
    output signed [SCALED_W-1:0] scaled
);

    localparam PROD_W = DIFF_W + GAIN_W + 1;

    /*
     * gain is an unsigned runtime scale factor.  Extend it by one leading
     * zero bit before casting to signed so that values such as 8'h80..8'hFF
     * remain positive signed values rather than becoming negative.
     */
    wire signed [GAIN_W:0] gain_signed;
    wire signed [PROD_W-1:0] product;

    assign gain_signed = $signed({1'b0, gain});
    assign product     = $signed(diff) * gain_signed;

    /*
     * With the default parameters SCALED_W == PROD_W, so this is the full
     * precision product.  If SCALED_W is overridden, Verilog assignment rules
     * perform the corresponding signed extension or truncation.
     */
    assign scaled = product;

endmodule