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

    function integer CLOG2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (CLOG2 = 1; v > 1; CLOG2 = CLOG2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam X_CNT_W  = CLOG2(IMG_WIDTH);
    localparam Y_CNT_W  = CLOG2(IMG_HEIGHT);
    localparam DIFF_W   = PIXEL_W + 1;
    localparam SCALED_W = DIFF_W + GAIN_W + 1;

    reg [X_CNT_W-1:0] x_count;
    reg [Y_CNT_W-1:0] y_count;

    reg [PIXEL_W-1:0] line1 [0:IMG_WIDTH-1];
    reg [PIXEL_W-1:0] line2 [0:IMG_WIDTH-1];

    reg [PIXEL_W-1:0] row0_d2;
    reg [PIXEL_W-1:0] row0_d1;
    reg [PIXEL_W-1:0] row1_d2;
    reg [PIXEL_W-1:0] row1_d1;
    reg [PIXEL_W-1:0] row2_d2;
    reg [PIXEL_W-1:0] row2_d1;

    wire [PIXEL_W-1:0] line1_rd;
    wire [PIXEL_W-1:0] line2_rd;

    assign line1_rd = line1[x_count];
    assign line2_rd = line2[x_count];

    wire x_ge_1;
    wire x_ge_2;
    wire y_ge_1;
    wire y_ge_2;

    assign x_ge_1 = (x_count != {X_CNT_W{1'b0}});
    assign x_ge_2 = (x_count > {{(X_CNT_W-1){1'b0}}, 1'b1});
    assign y_ge_1 = (y_count != {Y_CNT_W{1'b0}});
    assign y_ge_2 = (y_count > {{(Y_CNT_W-1){1'b0}}, 1'b1});

    wire [PIXEL_W-1:0] w00;
    wire [PIXEL_W-1:0] w01;
    wire [PIXEL_W-1:0] w02;
    wire [PIXEL_W-1:0] w10;
    wire [PIXEL_W-1:0] w11;
    wire [PIXEL_W-1:0] w12;
    wire [PIXEL_W-1:0] w20;
    wire [PIXEL_W-1:0] w21;
    wire [PIXEL_W-1:0] w22;
    wire [PIXEL_W-1:0] orig_pixel;

    usm_window_zero_pad #(
        .PIXEL_W(PIXEL_W)
    ) u_window_zero_pad (
        .raw_p00(row0_d2),
        .raw_p01(row0_d1),
        .raw_p02(line2_rd),
        .raw_p10(row1_d2),
        .raw_p11(row1_d1),
        .raw_p12(line1_rd),
        .raw_p20(row2_d2),
        .raw_p21(row2_d1),
        .raw_p22(pixel_in),
        .x_ge_1(x_ge_1),
        .x_ge_2(x_ge_2),
        .y_ge_1(y_ge_1),
        .y_ge_2(y_ge_2),
        .p00(w00),
        .p01(w01),
        .p02(w02),
        .p10(w10),
        .p11(w11),
        .p12(w12),
        .p20(w20),
        .p21(w21),
        .p22(w22),
        .orig_pixel(orig_pixel)
    );

    wire [PIXEL_W-1:0] blurred_pixel;

    usm_gaussian3x3_blur #(
        .PIXEL_W(PIXEL_W)
    ) u_gaussian3x3_blur (
        .p00(w00),
        .p01(w01),
        .p02(w02),
        .p10(w10),
        .p11(w11),
        .p12(w12),
        .p20(w20),
        .p21(w21),
        .p22(w22),
        .blurred(blurred_pixel)
    );

    wire signed [DIFF_W-1:0] high_freq;

    usm_highfreq_subtract #(
        .PIXEL_W(PIXEL_W),
        .DIFF_W(DIFF_W)
    ) u_highfreq_subtract (
        .orig(orig_pixel),
        .blurred(blurred_pixel),
        .diff(high_freq)
    );

    wire signed [SCALED_W-1:0] scaled_high_freq;

    usm_gain_scale #(
        .DIFF_W(DIFF_W),
        .GAIN_W(GAIN_W),
        .SCALED_W(SCALED_W)
    ) u_gain_scale (
        .diff(high_freq),
        .gain(gain),
        .scaled(scaled_high_freq)
    );

    usm_reconstruct_saturate #(
        .PIXEL_W(PIXEL_W),
        .SCALED_W(SCALED_W)
    ) u_reconstruct_saturate (
        .orig(orig_pixel),
        .scaled(scaled_high_freq),
        .pixel_out(pixel_out)
    );

    assign valid_out = valid_in & ~rst;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            x_count <= {X_CNT_W{1'b0}};
            y_count <= {Y_CNT_W{1'b0}};

            row0_d2 <= {PIXEL_W{1'b0}};
            row0_d1 <= {PIXEL_W{1'b0}};
            row1_d2 <= {PIXEL_W{1'b0}};
            row1_d1 <= {PIXEL_W{1'b0}};
            row2_d2 <= {PIXEL_W{1'b0}};
            row2_d1 <= {PIXEL_W{1'b0}};

            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                line1[i] <= {PIXEL_W{1'b0}};
                line2[i] <= {PIXEL_W{1'b0}};
            end
        end else if (valid_in) begin
            line2[x_count] <= line1_rd;
            line1[x_count] <= pixel_in;

            if (x_count == IMG_WIDTH-1) begin
                x_count <= {X_CNT_W{1'b0}};

                if (y_count == IMG_HEIGHT-1)
                    y_count <= {Y_CNT_W{1'b0}};
                else
                    y_count <= y_count + {{(Y_CNT_W-1){1'b0}}, 1'b1};

                row0_d2 <= {PIXEL_W{1'b0}};
                row0_d1 <= {PIXEL_W{1'b0}};
                row1_d2 <= {PIXEL_W{1'b0}};
                row1_d1 <= {PIXEL_W{1'b0}};
                row2_d2 <= {PIXEL_W{1'b0}};
                row2_d1 <= {PIXEL_W{1'b0}};
            end else begin
                x_count <= x_count + {{(X_CNT_W-1){1'b0}}, 1'b1};

                row0_d2 <= row0_d1;
                row0_d1 <= line2_rd;
                row1_d2 <= row1_d1;
                row1_d1 <= line1_rd;
                row2_d2 <= row2_d1;
                row2_d1 <= pixel_in;
            end
        end
    end

endmodule