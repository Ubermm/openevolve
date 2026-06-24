`timescale 1ns/1ps

module sobel3x3 #(
    parameter PIXEL_W = 8,
    parameter GRAD_W  = 16
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
    output signed [GRAD_W-1:0] gx,
    output signed [GRAD_W-1:0] gy
);

    /*
     * Sobel kernels:
     *
     *   Gx = [ -1  0 +1 ]   Gy = [ -1 -2 -1 ]
     *        [ -2  0 +2 ]        [  0  0  0 ]
     *        [ -1  0 +1 ]        [ +1 +2 +1 ]
     *
     * Maximum magnitude is 4 * (2^PIXEL_W - 1), so PIXEL_W+3 signed
     * bits are sufficient for the internal result.
     */
    localparam SUM_W = PIXEL_W + 3;

    wire signed [SUM_W-1:0] s00 = {{(SUM_W-PIXEL_W){1'b0}}, p00};
    wire signed [SUM_W-1:0] s01 = {{(SUM_W-PIXEL_W){1'b0}}, p01};
    wire signed [SUM_W-1:0] s02 = {{(SUM_W-PIXEL_W){1'b0}}, p02};
    wire signed [SUM_W-1:0] s10 = {{(SUM_W-PIXEL_W){1'b0}}, p10};
    wire signed [SUM_W-1:0] s12 = {{(SUM_W-PIXEL_W){1'b0}}, p12};
    wire signed [SUM_W-1:0] s20 = {{(SUM_W-PIXEL_W){1'b0}}, p20};
    wire signed [SUM_W-1:0] s21 = {{(SUM_W-PIXEL_W){1'b0}}, p21};
    wire signed [SUM_W-1:0] s22 = {{(SUM_W-PIXEL_W){1'b0}}, p22};

    wire signed [SUM_W-1:0] gx_int;
    wire signed [SUM_W-1:0] gy_int;

    assign gx_int = -s00 + s02
                    - (s10 <<< 1) + (s12 <<< 1)
                    - s20 + s22;

    assign gy_int = -s00 - (s01 <<< 1) - s02
                    + s20 + (s21 <<< 1) + s22;

    assign gx = gx_int;
    assign gy = gy_int;

    /*
     * p11 is intentionally unused by the Sobel operator.
     */
    wire unused_p11 = |p11;

endmodule