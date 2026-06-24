`timescale 1ns/1ps

module usm_gaussian3x3_blur #(
    parameter PIXEL_W = 8
) (
    input  [PIXEL_W-1:0] p00,
    input  [PIXEL_W-1:0] p01,
    input  [PIXEL_W-1:0] p02,
    input  [PIXEL_W-1:0] p10,
    input  [PIXEL_W-1:0] p11,
    input  [PIXEL_W-1:0] p12,
    input  [PIXEL_W-1:0] p20,
    input  [PIXEL_W-1:0] p21,
    input  [PIXEL_W-1:0] p22,
    output [PIXEL_W-1:0] blurred
);

    /*
        Gaussian 3x3 kernel:

            1 2 1
            2 4 2
            1 2 1

        Normalization factor = 16.

        The accumulator width is PIXEL_W + 5 bits:
        - PIXEL_W + 4 bits are enough for max value 16*((2^PIXEL_W)-1)
        - one extra bit is kept for the rounding add of 8
    */

    localparam SUM_W = PIXEL_W + 5;

    wire [SUM_W-1:0] p00_ext = {{(SUM_W-PIXEL_W){1'b0}}, p00};
    wire [SUM_W-1:0] p01_ext = {{(SUM_W-PIXEL_W){1'b0}}, p01};
    wire [SUM_W-1:0] p02_ext = {{(SUM_W-PIXEL_W){1'b0}}, p02};
    wire [SUM_W-1:0] p10_ext = {{(SUM_W-PIXEL_W){1'b0}}, p10};
    wire [SUM_W-1:0] p11_ext = {{(SUM_W-PIXEL_W){1'b0}}, p11};
    wire [SUM_W-1:0] p12_ext = {{(SUM_W-PIXEL_W){1'b0}}, p12};
    wire [SUM_W-1:0] p20_ext = {{(SUM_W-PIXEL_W){1'b0}}, p20};
    wire [SUM_W-1:0] p21_ext = {{(SUM_W-PIXEL_W){1'b0}}, p21};
    wire [SUM_W-1:0] p22_ext = {{(SUM_W-PIXEL_W){1'b0}}, p22};

    wire [SUM_W-1:0] weighted_sum;

    assign weighted_sum =
          p00_ext
        + (p01_ext << 1)
        + p02_ext
        + (p10_ext << 1)
        + (p11_ext << 2)
        + (p12_ext << 1)
        + p20_ext
        + (p21_ext << 1)
        + p22_ext;

    assign blurred = (weighted_sum + {{(SUM_W-4){1'b0}}, 4'd8}) >> 4;

endmodule