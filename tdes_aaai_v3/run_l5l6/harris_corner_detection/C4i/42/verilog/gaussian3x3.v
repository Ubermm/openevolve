`timescale 1ns/1ps

module gaussian3x3 #(
    parameter IN_W  = 32,
    parameter OUT_W = 32
) (
    input  signed [IN_W-1:0] v00,
    input  signed [IN_W-1:0] v01,
    input  signed [IN_W-1:0] v02,
    input  signed [IN_W-1:0] v10,
    input  signed [IN_W-1:0] v11,
    input  signed [IN_W-1:0] v12,
    input  signed [IN_W-1:0] v20,
    input  signed [IN_W-1:0] v21,
    input  signed [IN_W-1:0] v22,
    output signed [OUT_W-1:0] out
);

    /*
        Gaussian 3x3 kernel:

            1 2 1
            2 4 2
            1 2 1

        Normalized by 16.

        The weighted sum can be up to 16 times the input magnitude,
        so use a widened signed accumulator before the arithmetic shift.
    */
    localparam SUM_W = IN_W + 5;

    wire signed [SUM_W-1:0] e00;
    wire signed [SUM_W-1:0] e01;
    wire signed [SUM_W-1:0] e02;
    wire signed [SUM_W-1:0] e10;
    wire signed [SUM_W-1:0] e11;
    wire signed [SUM_W-1:0] e12;
    wire signed [SUM_W-1:0] e20;
    wire signed [SUM_W-1:0] e21;
    wire signed [SUM_W-1:0] e22;

    wire signed [SUM_W-1:0] sum;
    wire signed [SUM_W-1:0] normalized;

    assign e00 = {{(SUM_W-IN_W){v00[IN_W-1]}}, v00};
    assign e01 = {{(SUM_W-IN_W){v01[IN_W-1]}}, v01};
    assign e02 = {{(SUM_W-IN_W){v02[IN_W-1]}}, v02};

    assign e10 = {{(SUM_W-IN_W){v10[IN_W-1]}}, v10};
    assign e11 = {{(SUM_W-IN_W){v11[IN_W-1]}}, v11};
    assign e12 = {{(SUM_W-IN_W){v12[IN_W-1]}}, v12};

    assign e20 = {{(SUM_W-IN_W){v20[IN_W-1]}}, v20};
    assign e21 = {{(SUM_W-IN_W){v21[IN_W-1]}}, v21};
    assign e22 = {{(SUM_W-IN_W){v22[IN_W-1]}}, v22};

    assign sum =
          e00 + (e01 <<< 1) + e02
        + (e10 <<< 1) + (e11 <<< 2) + (e12 <<< 1)
        + e20 + (e21 <<< 1) + e22;

    assign normalized = sum >>> 4;

    assign out = normalized[OUT_W-1:0];

endmodule