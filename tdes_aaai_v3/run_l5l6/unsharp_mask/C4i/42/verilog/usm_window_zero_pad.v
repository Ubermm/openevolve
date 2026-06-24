`timescale 1ns/1ps

module usm_window_zero_pad #(
    parameter PIXEL_W = 8
) (
    input  [PIXEL_W-1:0] raw_p00,
    input  [PIXEL_W-1:0] raw_p01,
    input  [PIXEL_W-1:0] raw_p02,
    input  [PIXEL_W-1:0] raw_p10,
    input  [PIXEL_W-1:0] raw_p11,
    input  [PIXEL_W-1:0] raw_p12,
    input  [PIXEL_W-1:0] raw_p20,
    input  [PIXEL_W-1:0] raw_p21,
    input  [PIXEL_W-1:0] raw_p22,

    input                x_ge_1,
    input                x_ge_2,
    input                y_ge_1,
    input                y_ge_2,

    output [PIXEL_W-1:0] p00,
    output [PIXEL_W-1:0] p01,
    output [PIXEL_W-1:0] p02,
    output [PIXEL_W-1:0] p10,
    output [PIXEL_W-1:0] p11,
    output [PIXEL_W-1:0] p12,
    output [PIXEL_W-1:0] p20,
    output [PIXEL_W-1:0] p21,
    output [PIXEL_W-1:0] p22,

    output [PIXEL_W-1:0] orig_pixel
);

    localparam [PIXEL_W-1:0] ZERO = {PIXEL_W{1'b0}};

    assign p00 = (y_ge_2 && x_ge_2) ? raw_p00 : ZERO;
    assign p01 = (y_ge_2 && x_ge_1) ? raw_p01 : ZERO;
    assign p02 =  y_ge_2            ? raw_p02 : ZERO;

    assign p10 = (y_ge_1 && x_ge_2) ? raw_p10 : ZERO;
    assign p11 = (y_ge_1 && x_ge_1) ? raw_p11 : ZERO;
    assign p12 =  y_ge_1            ? raw_p12 : ZERO;

    assign p20 =  x_ge_2            ? raw_p20 : ZERO;
    assign p21 =  x_ge_1            ? raw_p21 : ZERO;
    assign p22 = raw_p22;

    assign orig_pixel = raw_p22;

endmodule