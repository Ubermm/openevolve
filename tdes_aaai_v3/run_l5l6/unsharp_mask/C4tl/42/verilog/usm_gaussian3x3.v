`timescale 1ns/1ps

module usm_gaussian3x3 #(
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
    output [PIXEL_W-1:0] blur
);

    localparam SUM_W = PIXEL_W + 4;

    wire [SUM_W-1:0] p00_z = {{(SUM_W-PIXEL_W){1'b0}}, p00};
    wire [SUM_W-1:0] p01_z = {{(SUM_W-PIXEL_W){1'b0}}, p01};
    wire [SUM_W-1:0] p02_z = {{(SUM_W-PIXEL_W){1'b0}}, p02};
    wire [SUM_W-1:0] p10_z = {{(SUM_W-PIXEL_W){1'b0}}, p10};
    wire [SUM_W-1:0] p11_z = {{(SUM_W-PIXEL_W){1'b0}}, p11};
    wire [SUM_W-1:0] p12_z = {{(SUM_W-PIXEL_W){1'b0}}, p12};
    wire [SUM_W-1:0] p20_z = {{(SUM_W-PIXEL_W){1'b0}}, p20};
    wire [SUM_W-1:0] p21_z = {{(SUM_W-PIXEL_W){1'b0}}, p21};
    wire [SUM_W-1:0] p22_z = {{(SUM_W-PIXEL_W){1'b0}}, p22};

    wire [SUM_W-1:0] sum;

    assign sum =
        p00_z         +
        (p01_z << 1)  +
        p02_z         +
        (p10_z << 1)  +
        (p11_z << 2)  +
        (p12_z << 1)  +
        p20_z         +
        (p21_z << 1)  +
        p22_z;

    assign blur = sum[PIXEL_W+3:4];

endmodule