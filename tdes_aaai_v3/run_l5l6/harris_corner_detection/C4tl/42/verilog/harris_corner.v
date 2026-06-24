`timescale 1ns/1ps

module harris_corner #(
    parameter IMG_WIDTH  = 128,
    parameter IMG_HEIGHT = 128,
    parameter PIXEL_W    = 8,
    parameter GRAD_W     = 16,
    parameter RESP_W     = 32,
    parameter K_W        = 8
) (
    input clk,
    input rst,
    input [PIXEL_W-1:0] pixel_in,
    input valid_in,
    input [RESP_W-1:0] threshold,
    input [K_W-1:0] k_param,
    output is_corner,
    output valid_out
);

    localparam PROD_W = 2 * GRAD_W;

    integer i;

    reg [31:0] col_count;
    reg [31:0] row_count;

    reg [PIXEL_W-1:0] pix_lb0 [0:IMG_WIDTH-1];
    reg [PIXEL_W-1:0] pix_lb1 [0:IMG_WIDTH-1];

    reg [PIXEL_W-1:0] pix_top_m1;
    reg [PIXEL_W-1:0] pix_top_m2;
    reg [PIXEL_W-1:0] pix_mid_m1;
    reg [PIXEL_W-1:0] pix_mid_m2;
    reg [PIXEL_W-1:0] pix_bot_m1;
    reg [PIXEL_W-1:0] pix_bot_m2;

    wire [PIXEL_W-1:0] pix_top_now = pix_lb1[col_count];
    wire [PIXEL_W-1:0] pix_mid_now = pix_lb0[col_count];

    wire [PIXEL_W-1:0] s1_p00 = (valid_in && (row_count >= 2) && (col_count >= 2)) ? pix_top_m2 : {PIXEL_W{1'b0}};
    wire [PIXEL_W-1:0] s1_p01 = (valid_in && (row_count >= 2) && (col_count >= 1)) ? pix_top_m1 : {PIXEL_W{1'b0}};
    wire [PIXEL_W-1:0] s1_p02 = (valid_in && (row_count >= 2))                     ? pix_top_now : {PIXEL_W{1'b0}};

    wire [PIXEL_W-1:0] s1_p10 = (valid_in && (row_count >= 1) && (col_count >= 2)) ? pix_mid_m2 : {PIXEL_W{1'b0}};
    wire [PIXEL_W-1:0] s1_p11 = (valid_in && (row_count >= 1) && (col_count >= 1)) ? pix_mid_m1 : {PIXEL_W{1'b0}};
    wire [PIXEL_W-1:0] s1_p12 = (valid_in && (row_count >= 1))                     ? pix_mid_now : {PIXEL_W{1'b0}};

    wire [PIXEL_W-1:0] s1_p20 = (valid_in && (col_count >= 2)) ? pix_bot_m2 : {PIXEL_W{1'b0}};
    wire [PIXEL_W-1:0] s1_p21 = (valid_in && (col_count >= 1)) ? pix_bot_m1 : {PIXEL_W{1'b0}};
    wire [PIXEL_W-1:0] s1_p22 = valid_in ? pixel_in : {PIXEL_W{1'b0}};

    wire signed [GRAD_W-1:0] grad_x;
    wire signed [GRAD_W-1:0] grad_y;

    harris_sobel3x3 #(
        .PIXEL_W(PIXEL_W),
        .GRAD_W(GRAD_W)
    ) u_sobel (
        .p00(s1_p00), .p01(s1_p01), .p02(s1_p02),
        .p10(s1_p10), .p11(s1_p11), .p12(s1_p12),
        .p20(s1_p20), .p21(s1_p21), .p22(s1_p22),
        .gx(grad_x),
        .gy(grad_y)
    );

    wire signed [PROD_W-1:0] prod_xx;
    wire signed [PROD_W-1:0] prod_yy;
    wire signed [PROD_W-1:0] prod_xy;

    harris_grad_products #(
        .GRAD_W(GRAD_W)
    ) u_products (
        .gx(grad_x),
        .gy(grad_y),
        .ix2(prod_xx),
        .iy2(prod_yy),
        .ixiy(prod_xy)
    );

    reg signed [PROD_W-1:0] xx_lb0 [0:IMG_WIDTH-1];
    reg signed [PROD_W-1:0] xx_lb1 [0:IMG_WIDTH-1];
    reg signed [PROD_W-1:0] yy_lb0 [0:IMG_WIDTH-1];
    reg signed [PROD_W-1:0] yy_lb1 [0:IMG_WIDTH-1];
    reg signed [PROD_W-1:0] xy_lb0 [0:IMG_WIDTH-1];
    reg signed [PROD_W-1:0] xy_lb1 [0:IMG_WIDTH-1];

    reg signed [PROD_W-1:0] xx_top_m1, xx_top_m2, xx_mid_m1, xx_mid_m2, xx_bot_m1, xx_bot_m2;
    reg signed [PROD_W-1:0] yy_top_m1, yy_top_m2, yy_mid_m1, yy_mid_m2, yy_bot_m1, yy_bot_m2;
    reg signed [PROD_W-1:0] xy_top_m1, xy_top_m2, xy_mid_m1, xy_mid_m2, xy_bot_m1, xy_bot_m2;

    wire signed [PROD_W-1:0] xx_top_now = xx_lb1[col_count];
    wire signed [PROD_W-1:0] xx_mid_now = xx_lb0[col_count];
    wire signed [PROD_W-1:0] yy_top_now = yy_lb1[col_count];
    wire signed [PROD_W-1:0] yy_mid_now = yy_lb0[col_count];
    wire signed [PROD_W-1:0] xy_top_now = xy_lb1[col_count];
    wire signed [PROD_W-1:0] xy_mid_now = xy_lb0[col_count];

    wire signed [PROD_W-1:0] zero_prod = {PROD_W{1'b0}};

    wire signed [PROD_W-1:0] xx_w00 = (valid_in && (row_count >= 2) && (col_count >= 2)) ? xx_top_m2  : zero_prod;
    wire signed [PROD_W-1:0] xx_w01 = (valid_in && (row_count >= 2) && (col_count >= 1)) ? xx_top_m1  : zero_prod;
    wire signed [PROD_W-1:0] xx_w02 = (valid_in && (row_count >= 2))                     ? xx_top_now : zero_prod;
    wire signed [PROD_W-1:0] xx_w10 = (valid_in && (row_count >= 1) && (col_count >= 2)) ? xx_mid_m2  : zero_prod;
    wire signed [PROD_W-1:0] xx_w11 = (valid_in && (row_count >= 1) && (col_count >= 1)) ? xx_mid_m1  : zero_prod;
    wire signed [PROD_W-1:0] xx_w12 = (valid_in && (row_count >= 1))                     ? xx_mid_now : zero_prod;
    wire signed [PROD_W-1:0] xx_w20 = (valid_in && (col_count >= 2)) ? xx_bot_m2 : zero_prod;
    wire signed [PROD_W-1:0] xx_w21 = (valid_in && (col_count >= 1)) ? xx_bot_m1 : zero_prod;
    wire signed [PROD_W-1:0] xx_w22 = valid_in ? prod_xx : zero_prod;

    wire signed [PROD_W-1:0] yy_w00 = (valid_in && (row_count >= 2) && (col_count >= 2)) ? yy_top_m2  : zero_prod;
    wire signed [PROD_W-1:0] yy_w01 = (valid_in && (row_count >= 2) && (col_count >= 1)) ? yy_top_m1  : zero_prod;
    wire signed [PROD_W-1:0] yy_w02 = (valid_in && (row_count >= 2))                     ? yy_top_now : zero_prod;
    wire signed [PROD_W-1:0] yy_w10 = (valid_in && (row_count >= 1) && (col_count >= 2)) ? yy_mid_m2  : zero_prod;
    wire signed [PROD_W-1:0] yy_w11 = (valid_in && (row_count >= 1) && (col_count >= 1)) ? yy_mid_m1  : zero_prod;
    wire signed [PROD_W-1:0] yy_w12 = (valid_in && (row_count >= 1))                     ? yy_mid_now : zero_prod;
    wire signed [PROD_W-1:0] yy_w20 = (valid_in && (col_count >= 2)) ? yy_bot_m2 : zero_prod;
    wire signed [PROD_W-1:0] yy_w21 = (valid_in && (col_count >= 1)) ? yy_bot_m1 : zero_prod;
    wire signed [PROD_W-1:0] yy_w22 = valid_in ? prod_yy : zero_prod;

    wire signed [PROD_W-1:0] xy_w00 = (valid_in && (row_count >= 2) && (col_count >= 2)) ? xy_top_m2  : zero_prod;
    wire signed [PROD_W-1:0] xy_w01 = (valid_in && (row_count >= 2) && (col_count >= 1)) ? xy_top_m1  : zero_prod;
    wire signed [PROD_W-1:0] xy_w02 = (valid_in && (row_count >= 2))                     ? xy_top_now : zero_prod;
    wire signed [PROD_W-1:0] xy_w10 = (valid_in && (row_count >= 1) && (col_count >= 2)) ? xy_mid_m2  : zero_prod;
    wire signed [PROD_W-1:0] xy_w11 = (valid_in && (row_count >= 1) && (col_count >= 1)) ? xy_mid_m1  : zero_prod;
    wire signed [PROD_W-1:0] xy_w12 = (valid_in && (row_count >= 1))                     ? xy_mid_now : zero_prod;
    wire signed [PROD_W-1:0] xy_w20 = (valid_in && (col_count >= 2)) ? xy_bot_m2 : zero_prod;
    wire signed [PROD_W-1:0] xy_w21 = (valid_in && (col_count >= 1)) ? xy_bot_m1 : zero_prod;
    wire signed [PROD_W-1:0] xy_w22 = valid_in ? prod_xy : zero_prod;

    wire signed [PROD_W-1:0] smooth_xx;
    wire signed [PROD_W-1:0] smooth_yy;
    wire signed [PROD_W-1:0] smooth_xy;

    harris_gaussian3x3 #(
        .IN_W(PROD_W)
    ) u_gauss_xx (
        .v00(xx_w00), .v01(xx_w01), .v02(xx_w02),
        .v10(xx_w10), .v11(xx_w11), .v12(xx_w12),
        .v20(xx_w20), .v21(xx_w21), .v22(xx_w22),
        .out(smooth_xx)
    );

    harris_gaussian3x3 #(
        .IN_W(PROD_W)
    ) u_gauss_yy (
        .v00(yy_w00), .v01(yy_w01), .v02(yy_w02),
        .v10(yy_w10), .v11(yy_w11), .v12(yy_w12),
        .v20(yy_w20), .v21(yy_w21), .v22(yy_w22),
        .out(smooth_yy)
    );

    harris_gaussian3x3 #(
        .IN_W(PROD_W)
    ) u_gauss_xy (
        .v00(xy_w00), .v01(xy_w01), .v02(xy_w02),
        .v10(xy_w10), .v11(xy_w11), .v12(xy_w12),
        .v20(xy_w20), .v21(xy_w21), .v22(xy_w22),
        .out(smooth_xy)
    );

    wire signed [RESP_W-1:0] response;

    harris_response #(
        .M_W(PROD_W),
        .RESP_W(RESP_W),
        .K_W(K_W),
        .K_FRAC(8),
        .RESP_SHIFT(16)
    ) u_response (
        .m_xx(smooth_xx),
        .m_yy(smooth_yy),
        .m_xy(smooth_xy),
        .k_param(k_param),
        .response(response)
    );

    wire corner_decision;

    harris_threshold #(
        .RESP_W(RESP_W)
    ) u_threshold (
        .response(response),
        .threshold(threshold),
        .is_corner(corner_decision)
    );

    wire stencil_region_valid;
    assign stencil_region_valid = valid_in &&
                                  (row_count >= 4) &&
                                  (col_count >= 4) &&
                                  (row_count < IMG_HEIGHT) &&
                                  (col_count < IMG_WIDTH);

    assign valid_out = valid_in & ~rst;
    assign is_corner = valid_out & stencil_region_valid & corner_decision;

    always @(posedge clk) begin
        if (rst) begin
            col_count <= 0;
            row_count <= 0;

            pix_top_m1 <= 0; pix_top_m2 <= 0;
            pix_mid_m1 <= 0; pix_mid_m2 <= 0;
            pix_bot_m1 <= 0; pix_bot_m2 <= 0;

            xx_top_m1 <= 0; xx_top_m2 <= 0; xx_mid_m1 <= 0; xx_mid_m2 <= 0; xx_bot_m1 <= 0; xx_bot_m2 <= 0;
            yy_top_m1 <= 0; yy_top_m2 <= 0; yy_mid_m1 <= 0; yy_mid_m2 <= 0; yy_bot_m1 <= 0; yy_bot_m2 <= 0;
            xy_top_m1 <= 0; xy_top_m2 <= 0; xy_mid_m1 <= 0; xy_mid_m2 <= 0; xy_bot_m1 <= 0; xy_bot_m2 <= 0;

            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                pix_lb0[i] <= 0;
                pix_lb1[i] <= 0;

                xx_lb0[i] <= 0;
                xx_lb1[i] <= 0;
                yy_lb0[i] <= 0;
                yy_lb1[i] <= 0;
                xy_lb0[i] <= 0;
                xy_lb1[i] <= 0;
            end
        end else if (valid_in) begin
            pix_lb1[col_count] <= pix_lb0[col_count];
            pix_lb0[col_count] <= pixel_in;

            xx_lb1[col_count] <= xx_lb0[col_count];
            xx_lb0[col_count] <= prod_xx;
            yy_lb1[col_count] <= yy_lb0[col_count];
            yy_lb0[col_count] <= prod_yy;
            xy_lb1[col_count] <= xy_lb0[col_count];
            xy_lb0[col_count] <= prod_xy;

            if (col_count == 0) begin
                pix_top_m2 <= 0;
                pix_top_m1 <= pix_top_now;
                pix_mid_m2 <= 0;
                pix_mid_m1 <= pix_mid_now;
                pix_bot_m2 <= 0;
                pix_bot_m1 <= pixel_in;

                xx_top_m2 <= 0;
                xx_top_m1 <= xx_top_now;
                xx_mid_m2 <= 0;
                xx_mid_m1 <= xx_mid_now;
                xx_bot_m2 <= 0;
                xx_bot_m1 <= prod_xx;

                yy_top_m2 <= 0;
                yy_top_m1 <= yy_top_now;
                yy_mid_m2 <= 0;
                yy_mid_m1 <= yy_mid_now;
                yy_bot_m2 <= 0;
                yy_bot_m1 <= prod_yy;

                xy_top_m2 <= 0;
                xy_top_m1 <= xy_top_now;
                xy_mid_m2 <= 0;
                xy_mid_m1 <= xy_mid_now;
                xy_bot_m2 <= 0;
                xy_bot_m1 <= prod_xy;
            end else begin
                pix_top_m2 <= pix_top_m1;
                pix_top_m1 <= pix_top_now;
                pix_mid_m2 <= pix_mid_m1;
                pix_mid_m1 <= pix_mid_now;
                pix_bot_m2 <= pix_bot_m1;
                pix_bot_m1 <= pixel_in;

                xx_top_m2 <= xx_top_m1;
                xx_top_m1 <= xx_top_now;
                xx_mid_m2 <= xx_mid_m1;
                xx_mid_m1 <= xx_mid_now;
                xx_bot_m2 <= xx_bot_m1;
                xx_bot_m1 <= prod_xx;

                yy_top_m2 <= yy_top_m1;
                yy_top_m1 <= yy_top_now;
                yy_mid_m2 <= yy_mid_m1;
                yy_mid_m1 <= yy_mid_now;
                yy_bot_m2 <= yy_bot_m1;
                yy_bot_m1 <= prod_yy;

                xy_top_m2 <= xy_top_m1;
                xy_top_m1 <= xy_top_now;
                xy_mid_m2 <= xy_mid_m1;
                xy_mid_m1 <= xy_mid_now;
                xy_bot_m2 <= xy_bot_m1;
                xy_bot_m1 <= prod_xy;
            end

            if (col_count == IMG_WIDTH-1) begin
                col_count <= 0;
                if (row_count == IMG_HEIGHT-1)
                    row_count <= 0;
                else
                    row_count <= row_count + 1;
            end else begin
                col_count <= col_count + 1;
            end
        end
    end

endmodule