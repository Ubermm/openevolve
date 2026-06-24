`timescale 1ns/1ps

module harris_sobel3x3 #(
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
    output reg signed [GRAD_W-1:0] gx,
    output reg signed [GRAD_W-1:0] gy
);

    /*
     * Sobel coefficient sum magnitude is 4:
     *
     *   max |Gx| or |Gy| = 4 * ((2^PIXEL_W) - 1)
     *
     * This requires PIXEL_W+3 signed bits.
     * Use at least GRAD_W bits as well so normal configurations do not
     * introduce unnecessary truncation.
     */
    localparam integer ACC_W =
        ((PIXEL_W + 3) > GRAD_W) ? (PIXEL_W + 3) : GRAD_W;

    wire signed [ACC_W-1:0] p00_s = {{(ACC_W-PIXEL_W){1'b0}}, p00};
    wire signed [ACC_W-1:0] p01_s = {{(ACC_W-PIXEL_W){1'b0}}, p01};
    wire signed [ACC_W-1:0] p02_s = {{(ACC_W-PIXEL_W){1'b0}}, p02};
    wire signed [ACC_W-1:0] p10_s = {{(ACC_W-PIXEL_W){1'b0}}, p10};
    wire signed [ACC_W-1:0] p12_s = {{(ACC_W-PIXEL_W){1'b0}}, p12};
    wire signed [ACC_W-1:0] p20_s = {{(ACC_W-PIXEL_W){1'b0}}, p20};
    wire signed [ACC_W-1:0] p21_s = {{(ACC_W-PIXEL_W){1'b0}}, p21};
    wire signed [ACC_W-1:0] p22_s = {{(ACC_W-PIXEL_W){1'b0}}, p22};

    reg signed [ACC_W-1:0] sx;
    reg signed [ACC_W-1:0] sy;

    always @* begin
        /*
         * Gx kernel:
         *   [-1  0 +1]
         *   [-2  0 +2]
         *   [-1  0 +1]
         */
        sx = -p00_s + p02_s
             - (p10_s <<< 1) + (p12_s <<< 1)
             - p20_s + p22_s;

        /*
         * Gy kernel:
         *   [-1 -2 -1]
         *   [ 0  0  0]
         *   [+1 +2 +1]
         */
        sy = -p00_s - (p01_s <<< 1) - p02_s
             + p20_s + (p21_s <<< 1) + p22_s;

        gx = sx[GRAD_W-1:0];
        gy = sy[GRAD_W-1:0];
    end

endmodule