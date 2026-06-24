`timescale 1ns/1ps

module unsharp_mask #(
    parameter IMG_WIDTH  = 256,
    parameter IMG_HEIGHT = 256,
    parameter PIXEL_W    = 8,
    parameter GAIN_W     = 8
) (
    input clk,
    input rst,
    input [PIXEL_W-1:0] pixel_in,
    input valid_in,
    input [GAIN_W-1:0] gain,
    output [PIXEL_W-1:0] pixel_out,
    output valid_out
);

    localparam DIFF_W  = PIXEL_W + 1;
    localparam SCALE_W = PIXEL_W + GAIN_W + 2;

    reg [PIXEL_W-1:0] line0 [0:IMG_WIDTH-1];
    reg [PIXEL_W-1:0] line1 [0:IMG_WIDTH-1];

    reg [PIXEL_W-1:0] top_prev1;
    reg [PIXEL_W-1:0] top_prev2;
    reg [PIXEL_W-1:0] mid_prev1;
    reg [PIXEL_W-1:0] mid_prev2;
    reg [PIXEL_W-1:0] bot_prev1;
    reg [PIXEL_W-1:0] bot_prev2;

    reg [31:0] col_count;
    reg [31:0] row_count;

    integer i;

    wire [PIXEL_W-1:0] zero_pix;
    assign zero_pix = {PIXEL_W{1'b0}};

    wire [PIXEL_W-1:0] top_cur;
    wire [PIXEL_W-1:0] mid_cur;
    wire [PIXEL_W-1:0] bot_cur;

    assign top_cur = (row_count >= 2) ? line1[col_count] : zero_pix;
    assign mid_cur = (row_count >= 1) ? line0[col_count] : zero_pix;
    assign bot_cur = pixel_in;

    wire [PIXEL_W-1:0] w00;
    wire [PIXEL_W-1:0] w01;
    wire [PIXEL_W-1:0] w02;
    wire [PIXEL_W-1:0] w10;
    wire [PIXEL_W-1:0] w11;
    wire [PIXEL_W-1:0] w12;
    wire [PIXEL_W-1:0] w20;
    wire [PIXEL_W-1:0] w21;
    wire [PIXEL_W-1:0] w22;

    assign w00 = ((row_count >= 2) && (col_count >= 2)) ? top_prev2 : zero_pix;
    assign w01 = ((row_count >= 2) && (col_count >= 1)) ? top_prev1 : zero_pix;
    assign w02 = top_cur;

    assign w10 = ((row_count >= 1) && (col_count >= 2)) ? mid_prev2 : zero_pix;
    assign w11 = ((row_count >= 1) && (col_count >= 1)) ? mid_prev1 : zero_pix;
    assign w12 = mid_cur;

    assign w20 = (col_count >= 2) ? bot_prev2 : zero_pix;
    assign w21 = (col_count >= 1) ? bot_prev1 : zero_pix;
    assign w22 = bot_cur;

    wire [PIXEL_W-1:0] blur_pixel;
    wire signed [DIFF_W-1:0] high_freq;
    wire signed [SCALE_W-1:0] scaled_high;

    usm_gaussian3x3 #(
        .PIXEL_W(PIXEL_W)
    ) u_stencil_gaussian (
        .p00(w00), .p01(w01), .p02(w02),
        .p10(w10), .p11(w11), .p12(w12),
        .p20(w20), .p21(w21), .p22(w22),
        .blur(blur_pixel)
    );

    usm_highpass #(
        .PIXEL_W(PIXEL_W)
    ) u_pointwise_subtract (
        .orig(pixel_in),
        .blur(blur_pixel),
        .diff(high_freq)
    );

    usm_gain_scale #(
        .PIXEL_W(PIXEL_W),
        .GAIN_W(GAIN_W)
    ) u_pointwise_gain (
        .diff(high_freq),
        .gain(gain),
        .scaled(scaled_high)
    );

    usm_reconstruct_sat #(
        .PIXEL_W(PIXEL_W),
        .GAIN_W(GAIN_W)
    ) u_pointwise_reconstruct (
        .orig(pixel_in),
        .scaled(scaled_high),
        .pixel_out(pixel_out)
    );

    assign valid_out = valid_in & ~rst;

    always @(negedge clk or posedge rst) begin
        if (rst) begin
            col_count <= 0;
            row_count <= 0;

            top_prev1 <= zero_pix;
            top_prev2 <= zero_pix;
            mid_prev1 <= zero_pix;
            mid_prev2 <= zero_pix;
            bot_prev1 <= zero_pix;
            bot_prev2 <= zero_pix;

            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                line0[i] <= zero_pix;
                line1[i] <= zero_pix;
            end
        end else begin
            if (valid_in) begin
                line1[col_count] <= line0[col_count];
                line0[col_count] <= pixel_in;

                if (col_count == IMG_WIDTH-1) begin
                    col_count <= 0;

                    if (row_count == IMG_HEIGHT-1)
                        row_count <= 0;
                    else
                        row_count <= row_count + 1;

                    top_prev1 <= zero_pix;
                    top_prev2 <= zero_pix;
                    mid_prev1 <= zero_pix;
                    mid_prev2 <= zero_pix;
                    bot_prev1 <= zero_pix;
                    bot_prev2 <= zero_pix;
                end else begin
                    col_count <= col_count + 1;

                    top_prev2 <= top_prev1;
                    top_prev1 <= (row_count >= 2) ? line1[col_count] : zero_pix;

                    mid_prev2 <= mid_prev1;
                    mid_prev1 <= (row_count >= 1) ? line0[col_count] : zero_pix;

                    bot_prev2 <= bot_prev1;
                    bot_prev1 <= pixel_in;
                end
            end
        end
    end

endmodule