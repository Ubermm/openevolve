module gs_direct_solve_2x2 #(
    parameter DATA_WIDTH = 32,
    parameter FRAC = 16
)(
    input  signed [DATA_WIDTH-1:0] a11,
    input  signed [DATA_WIDTH-1:0] a12,
    input  signed [DATA_WIDTH-1:0] a21,
    input  signed [DATA_WIDTH-1:0] a22,
    input  signed [DATA_WIDTH-1:0] b1,
    input  signed [DATA_WIDTH-1:0] b2,
    output reg signed [DATA_WIDTH-1:0] x1_direct,
    output reg signed [DATA_WIDTH-1:0] x2_direct
);

    localparam PROD_WIDTH = 2 * DATA_WIDTH;
    localparam DET_WIDTH  = (2 * DATA_WIDTH) + 1;
    localparam WIDE_WIDTH = 4 * DATA_WIDTH;

    reg signed [PROD_WIDTH-1:0] prod_det_1;
    reg signed [PROD_WIDTH-1:0] prod_det_2;
    reg signed [PROD_WIDTH-1:0] prod_num1_1;
    reg signed [PROD_WIDTH-1:0] prod_num1_2;
    reg signed [PROD_WIDTH-1:0] prod_num2_1;
    reg signed [PROD_WIDTH-1:0] prod_num2_2;

    reg signed [DET_WIDTH-1:0] det;
    reg signed [DET_WIDTH-1:0] num1;
    reg signed [DET_WIDTH-1:0] num2;

    reg signed [WIDE_WIDTH-1:0] det_wide;
    reg signed [WIDE_WIDTH-1:0] num1_scaled;
    reg signed [WIDE_WIDTH-1:0] num2_scaled;
    reg signed [WIDE_WIDTH-1:0] x1_quot;
    reg signed [WIDE_WIDTH-1:0] x2_quot;

    always @* begin
        prod_det_1  = a11 * a22;
        prod_det_2  = a12 * a21;

        prod_num1_1 = b1  * a22;
        prod_num1_2 = a12 * b2;

        prod_num2_1 = a11 * b2;
        prod_num2_2 = b1  * a21;

        det  = {prod_det_1[PROD_WIDTH-1],  prod_det_1}  - {prod_det_2[PROD_WIDTH-1],  prod_det_2};
        num1 = {prod_num1_1[PROD_WIDTH-1], prod_num1_1} - {prod_num1_2[PROD_WIDTH-1], prod_num1_2};
        num2 = {prod_num2_1[PROD_WIDTH-1], prod_num2_1} - {prod_num2_2[PROD_WIDTH-1], prod_num2_2};

        det_wide    = {{(WIDE_WIDTH-DET_WIDTH){det[DET_WIDTH-1]}},  det};
        num1_scaled = {{(WIDE_WIDTH-DET_WIDTH){num1[DET_WIDTH-1]}}, num1} <<< FRAC;
        num2_scaled = {{(WIDE_WIDTH-DET_WIDTH){num2[DET_WIDTH-1]}}, num2} <<< FRAC;

        x1_quot = {WIDE_WIDTH{1'b0}};
        x2_quot = {WIDE_WIDTH{1'b0}};

        if (det != {DET_WIDTH{1'b0}}) begin
            x1_quot = num1_scaled / det_wide;
            x2_quot = num2_scaled / det_wide;
        end

        x1_direct = x1_quot[DATA_WIDTH-1:0];
        x2_direct = x2_quot[DATA_WIDTH-1:0];
    end

endmodule