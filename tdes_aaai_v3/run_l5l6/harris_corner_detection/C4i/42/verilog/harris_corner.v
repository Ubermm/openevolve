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

    reg [31:0] col_cnt;
    reg [31:0] row_cnt;

    /*
     * Pixel line buffers.
     * pix_lb1 stores previous image row.
     * pix_lb2 stores row before previous image row.
     */
    reg [PIXEL_W-1:0] pix_lb1 [0:IMG_WIDTH-1];
    reg [PIXEL_W-1:0] pix_lb2 [0:IMG_WIDTH-1];

    wire [PIXEL_W-1:0] pix_prev_row;
    wire [PIXEL_W-1:0] pix_prev2_row;

    assign pix_prev_row  = pix_lb1[col_cnt];
    assign pix_prev2_row = pix_lb2[col_cnt];

    /*
     * 3x3 pixel stencil registers.
     */
    reg [PIXEL_W-1:0] p00, p01, p02;
    reg [PIXEL_W-1:0] p10, p11, p12;
    reg [PIXEL_W-1:0] p20, p21, p22;

    wire signed [GRAD_W-1:0] gx;
    wire signed [GRAD_W-1:0] gy;

    sobel3x3 #(
        .PIXEL_W(PIXEL_W),
        .GRAD_W (GRAD_W)
    ) u_sobel3x3 (
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .gx(gx),
        .gy(gy)
    );

    wire [PROD_W-1:0] ix2_now;
    wire [PROD_W-1:0] iy2_now;
    wire signed [PROD_W-1:0] ixiy_now;

    grad_products #(
        .GRAD_W(GRAD_W),
        .PROD_W(PROD_W)
    ) u_grad_products (
        .gx(gx),
        .gy(gy),
        .ix2(ix2_now),
        .iy2(iy2_now),
        .ixiy(ixiy_now)
    );

    /*
     * Product line buffers for Gaussian smoothing of Ix^2, Iy^2, and IxIy.
     */
    reg [PROD_W-1:0] ix2_lb1 [0:IMG_WIDTH-1];
    reg [PROD_W-1:0] ix2_lb2 [0:IMG_WIDTH-1];

    reg [PROD_W-1:0] iy2_lb1 [0:IMG_WIDTH-1];
    reg [PROD_W-1:0] iy2_lb2 [0:IMG_WIDTH-1];

    reg signed [PROD_W-1:0] ixiy_lb1 [0:IMG_WIDTH-1];
    reg signed [PROD_W-1:0] ixiy_lb2 [0:IMG_WIDTH-1];

    wire [PROD_W-1:0] ix2_prev_row;
    wire [PROD_W-1:0] ix2_prev2_row;
    wire [PROD_W-1:0] iy2_prev_row;
    wire [PROD_W-1:0] iy2_prev2_row;
    wire signed [PROD_W-1:0] ixiy_prev_row;
    wire signed [PROD_W-1:0] ixiy_prev2_row;

    assign ix2_prev_row   = ix2_lb1[col_cnt];
    assign ix2_prev2_row  = ix2_lb2[col_cnt];
    assign iy2_prev_row   = iy2_lb1[col_cnt];
    assign iy2_prev2_row  = iy2_lb2[col_cnt];
    assign ixiy_prev_row  = ixiy_lb1[col_cnt];
    assign ixiy_prev2_row = ixiy_lb2[col_cnt];

    /*
     * 3x3 product stencil registers.
     */
    reg [PROD_W-1:0] ix2_00, ix2_01, ix2_02;
    reg [PROD_W-1:0] ix2_10, ix2_11, ix2_12;
    reg [PROD_W-1:0] ix2_20, ix2_21, ix2_22;

    reg [PROD_W-1:0] iy2_00, iy2_01, iy2_02;
    reg [PROD_W-1:0] iy2_10, iy2_11, iy2_12;
    reg [PROD_W-1:0] iy2_20, iy2_21, iy2_22;

    reg signed [PROD_W-1:0] ixiy_00, ixiy_01, ixiy_02;
    reg signed [PROD_W-1:0] ixiy_10, ixiy_11, ixiy_12;
    reg signed [PROD_W-1:0] ixiy_20, ixiy_21, ixiy_22;

    wire signed [PROD_W-1:0] s_ix2;
    wire signed [PROD_W-1:0] s_iy2;
    wire signed [PROD_W-1:0] s_ixiy;

    gaussian3x3 #(
        .IN_W(PROD_W),
        .OUT_W(PROD_W)
    ) u_gauss_ix2 (
        .v00($signed(ix2_00)), .v01($signed(ix2_01)), .v02($signed(ix2_02)),
        .v10($signed(ix2_10)), .v11($signed(ix2_11)), .v12($signed(ix2_12)),
        .v20($signed(ix2_20)), .v21($signed(ix2_21)), .v22($signed(ix2_22)),
        .out(s_ix2)
    );

    gaussian3x3 #(
        .IN_W(PROD_W),
        .OUT_W(PROD_W)
    ) u_gauss_iy2 (
        .v00($signed(iy2_00)), .v01($signed(iy2_01)), .v02($signed(iy2_02)),
        .v10($signed(iy2_10)), .v11($signed(iy2_11)), .v12($signed(iy2_12)),
        .v20($signed(iy2_20)), .v21($signed(iy2_21)), .v22($signed(iy2_22)),
        .out(s_iy2)
    );

    gaussian3x3 #(
        .IN_W(PROD_W),
        .OUT_W(PROD_W)
    ) u_gauss_ixiy (
        .v00(ixiy_00), .v01(ixiy_01), .v02(ixiy_02),
        .v10(ixiy_10), .v11(ixiy_11), .v12(ixiy_12),
        .v20(ixiy_20), .v21(ixiy_21), .v22(ixiy_22),
        .out(s_ixiy)
    );

    wire [RESP_W-1:0] response;

    harris_response_comb #(
        .IN_W(PROD_W),
        .RESP_W(RESP_W),
        .K_W(K_W)
    ) u_harris_response (
        .ix2(s_ix2),
        .iy2(s_iy2),
        .ixiy(s_ixiy),
        .k_param(k_param),
        .response(response)
    );

    wire threshold_corner;

    harris_threshold_comb #(
        .RESP_W(RESP_W)
    ) u_threshold (
        .response(response),
        .threshold(threshold),
        .is_corner(threshold_corner)
    );

    reg region_valid;

    assign valid_out = valid_in;
    assign is_corner = valid_in & region_valid & threshold_corner;

    always @(posedge clk) begin
        if (rst) begin
            col_cnt <= 0;
            row_cnt <= 0;
            region_valid <= 1'b0;

            p00 <= 0; p01 <= 0; p02 <= 0;
            p10 <= 0; p11 <= 0; p12 <= 0;
            p20 <= 0; p21 <= 0; p22 <= 0;

            ix2_00 <= 0; ix2_01 <= 0; ix2_02 <= 0;
            ix2_10 <= 0; ix2_11 <= 0; ix2_12 <= 0;
            ix2_20 <= 0; ix2_21 <= 0; ix2_22 <= 0;

            iy2_00 <= 0; iy2_01 <= 0; iy2_02 <= 0;
            iy2_10 <= 0; iy2_11 <= 0; iy2_12 <= 0;
            iy2_20 <= 0; iy2_21 <= 0; iy2_22 <= 0;

            ixiy_00 <= 0; ixiy_01 <= 0; ixiy_02 <= 0;
            ixiy_10 <= 0; ixiy_11 <= 0; ixiy_12 <= 0;
            ixiy_20 <= 0; ixiy_21 <= 0; ixiy_22 <= 0;

            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                pix_lb1[i] <= 0;
                pix_lb2[i] <= 0;

                ix2_lb1[i] <= 0;
                ix2_lb2[i] <= 0;
                iy2_lb1[i] <= 0;
                iy2_lb2[i] <= 0;
                ixiy_lb1[i] <= 0;
                ixiy_lb2[i] <= 0;
            end
        end else begin
            if (valid_in) begin
                /*
                 * Update pixel line buffers.
                 */
                pix_lb2[col_cnt] <= pix_lb1[col_cnt];
                pix_lb1[col_cnt] <= pixel_in;

                /*
                 * Shift pixel stencil.  The first two columns of every row are
                 * padded with zeros to avoid wraparound across row boundaries.
                 */
                if (col_cnt == 0) begin
                    p00 <= 0; p01 <= 0; p02 <= pix_prev2_row;
                    p10 <= 0; p11 <= 0; p12 <= pix_prev_row;
                    p20 <= 0; p21 <= 0; p22 <= pixel_in;
                end else if (col_cnt == 1) begin
                    p00 <= 0;   p01 <= p02; p02 <= pix_prev2_row;
                    p10 <= 0;   p11 <= p12; p12 <= pix_prev_row;
                    p20 <= 0;   p21 <= p22; p22 <= pixel_in;
                end else begin
                    p00 <= p01; p01 <= p02; p02 <= pix_prev2_row;
                    p10 <= p11; p11 <= p12; p12 <= pix_prev_row;
                    p20 <= p21; p21 <= p22; p22 <= pixel_in;
                end

                /*
                 * Update product line buffers.
                 */
                ix2_lb2[col_cnt]  <= ix2_lb1[col_cnt];
                ix2_lb1[col_cnt]  <= ix2_now;
                iy2_lb2[col_cnt]  <= iy2_lb1[col_cnt];
                iy2_lb1[col_cnt]  <= iy2_now;
                ixiy_lb2[col_cnt] <= ixiy_lb1[col_cnt];
                ixiy_lb1[col_cnt] <= ixiy_now;

                /*
                 * Shift product stencil for Gaussian smoothing.
                 */
                if (col_cnt == 0) begin
                    ix2_00 <= 0; ix2_01 <= 0; ix2_02 <= ix2_prev2_row;
                    ix2_10 <= 0; ix2_11 <= 0; ix2_12 <= ix2_prev_row;
                    ix2_20 <= 0; ix2_21 <= 0; ix2_22 <= ix2_now;

                    iy2_00 <= 0; iy2_01 <= 0; iy2_02 <= iy2_prev2_row;
                    iy2_10 <= 0; iy2_11 <= 0; iy2_12 <= iy2_prev_row;
                    iy2_20 <= 0; iy2_21 <= 0; iy2_22 <= iy2_now;

                    ixiy_00 <= 0; ixiy_01 <= 0; ixiy_02 <= ixiy_prev2_row;
                    ixiy_10 <= 0; ixiy_11 <= 0; ixiy_12 <= ixiy_prev_row;
                    ixiy_20 <= 0; ixiy_21 <= 0; ixiy_22 <= ixiy_now;
                end else if (col_cnt == 1) begin
                    ix2_00 <= 0;      ix2_01 <= ix2_02; ix2_02 <= ix2_prev2_row;
                    ix2_10 <= 0;      ix2_11 <= ix2_12; ix2_12 <= ix2_prev_row;
                    ix2_20 <= 0;      ix2_21 <= ix2_22; ix2_22 <= ix2_now;

                    iy2_00 <= 0;      iy2_01 <= iy2_02; iy2_02 <= iy2_prev2_row;
                    iy2_10 <= 0;      iy2_11 <= iy2_12; iy2_12 <= iy2_prev_row;
                    iy2_20 <= 0;      iy2_21 <= iy2_22; iy2_22 <= iy2_now;

                    ixiy_00 <= 0;     ixiy_01 <= ixiy_02; ixiy_02 <= ixiy_prev2_row;
                    ixiy_10 <= 0;     ixiy_11 <= ixiy_12; ixiy_12 <= ixiy_prev_row;
                    ixiy_20 <= 0;     ixiy_21 <= ixiy_22; ixiy_22 <= ixiy_now;
                end else begin
                    ix2_00 <= ix2_01; ix2_01 <= ix2_02; ix2_02 <= ix2_prev2_row;
                    ix2_10 <= ix2_11; ix2_11 <= ix2_12; ix2_12 <= ix2_prev_row;
                    ix2_20 <= ix2_21; ix2_21 <= ix2_22; ix2_22 <= ix2_now;

                    iy2_00 <= iy2_01; iy2_01 <= iy2_02; iy2_02 <= iy2_prev2_row;
                    iy2_10 <= iy2_11; iy2_11 <= iy2_12; iy2_12 <= iy2_prev_row;
                    iy2_20 <= iy2_21; iy2_21 <= iy2_22; iy2_22 <= iy2_now;

                    ixiy_00 <= ixiy_01; ixiy_01 <= ixiy_02; ixiy_02 <= ixiy_prev2_row;
                    ixiy_10 <= ixiy_11; ixiy_11 <= ixiy_12; ixiy_12 <= ixiy_prev_row;
                    ixiy_20 <= ixiy_21; ixiy_21 <= ixiy_22; ixiy_22 <= ixiy_now;
                end

                /*
                 * Valid inner response after both 3x3 stencil stages are filled.
                 */
                if ((row_cnt >= 4) && (col_cnt >= 4))
                    region_valid <= 1'b1;
                else
                    region_valid <= 1'b0;

                /*
                 * Raster position update.
                 */
                if (col_cnt == IMG_WIDTH - 1) begin
                    col_cnt <= 0;
                    if (row_cnt == IMG_HEIGHT - 1)
                        row_cnt <= 0;
                    else
                        row_cnt <= row_cnt + 1;
                end else begin
                    col_cnt <= col_cnt + 1;
                end
            end else begin
                region_valid <= 1'b0;
            end
        end
    end

endmodule