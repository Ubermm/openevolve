`timescale 1ns/1ps

module dct8_dot_product #(
    parameter DATA_W  = 12,
    parameter COEFF_W = 16,
    parameter ACC_W   = DATA_W + COEFF_W + 4
) (
    input  signed [DATA_W-1:0]  x0,
    input  signed [DATA_W-1:0]  x1,
    input  signed [DATA_W-1:0]  x2,
    input  signed [DATA_W-1:0]  x3,
    input  signed [DATA_W-1:0]  x4,
    input  signed [DATA_W-1:0]  x5,
    input  signed [DATA_W-1:0]  x6,
    input  signed [DATA_W-1:0]  x7,

    input  signed [COEFF_W-1:0] c0,
    input  signed [COEFF_W-1:0] c1,
    input  signed [COEFF_W-1:0] c2,
    input  signed [COEFF_W-1:0] c3,
    input  signed [COEFF_W-1:0] c4,
    input  signed [COEFF_W-1:0] c5,
    input  signed [COEFF_W-1:0] c6,
    input  signed [COEFF_W-1:0] c7,

    output signed [ACC_W-1:0]   acc
);

    localparam PROD_W = DATA_W + COEFF_W;

    wire signed [PROD_W-1:0] p0;
    wire signed [PROD_W-1:0] p1;
    wire signed [PROD_W-1:0] p2;
    wire signed [PROD_W-1:0] p3;
    wire signed [PROD_W-1:0] p4;
    wire signed [PROD_W-1:0] p5;
    wire signed [PROD_W-1:0] p6;
    wire signed [PROD_W-1:0] p7;

    assign p0 = x0 * c0;
    assign p1 = x1 * c1;
    assign p2 = x2 * c2;
    assign p3 = x3 * c3;
    assign p4 = x4 * c4;
    assign p5 = x5 * c5;
    assign p6 = x6 * c6;
    assign p7 = x7 * c7;

    wire signed [ACC_W-1:0] a0;
    wire signed [ACC_W-1:0] a1;
    wire signed [ACC_W-1:0] a2;
    wire signed [ACC_W-1:0] a3;
    wire signed [ACC_W-1:0] a4;
    wire signed [ACC_W-1:0] a5;
    wire signed [ACC_W-1:0] a6;
    wire signed [ACC_W-1:0] a7;

    assign a0 = p0;
    assign a1 = p1;
    assign a2 = p2;
    assign a3 = p3;
    assign a4 = p4;
    assign a5 = p5;
    assign a6 = p6;
    assign a7 = p7;

    assign acc = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;

endmodule