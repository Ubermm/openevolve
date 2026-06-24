`timescale 1ns/1ps

module gs_direct_2x2_solver #(
    parameter DATA_WIDTH = 32,
    parameter FRAC       = 16
)(
    input  signed [DATA_WIDTH-1:0] a11,
    input  signed [DATA_WIDTH-1:0] a12,
    input  signed [DATA_WIDTH-1:0] a21,
    input  signed [DATA_WIDTH-1:0] a22,
    input  signed [DATA_WIDTH-1:0] b1,
    input  signed [DATA_WIDTH-1:0] b2,
    output signed [DATA_WIDTH-1:0] x1_direct,
    output signed [DATA_WIDTH-1:0] x2_direct
);

    localparam PROD_WIDTH = 2 * DATA_WIDTH;
    localparam DIFF_WIDTH = PROD_WIDTH + 1;
    localparam DIV_WIDTH  = DIFF_WIDTH + FRAC + 1;

    wire signed [PROD_WIDTH-1:0] prod_a11_a22 = a11 * a22;
    wire signed [PROD_WIDTH-1:0] prod_a12_a21 = a12 * a21;

    wire signed [PROD_WIDTH-1:0] prod_b1_a22  = b1  * a22;
    wire signed [PROD_WIDTH-1:0] prod_b2_a12  = b2  * a12;
    wire signed [PROD_WIDTH-1:0] prod_a11_b2  = a11 * b2;
    wire signed [PROD_WIDTH-1:0] prod_a21_b1  = a21 * b1;

    wire signed [DIFF_WIDTH-1:0] det_term_0 =
        {prod_a11_a22[PROD_WIDTH-1], prod_a11_a22};
    wire signed [DIFF_WIDTH-1:0] det_term_1 =
        {prod_a12_a21[PROD_WIDTH-1], prod_a12_a21};

    wire signed [DIFF_WIDTH-1:0] num1_term_0 =
        {prod_b1_a22[PROD_WIDTH-1], prod_b1_a22};
    wire signed [DIFF_WIDTH-1:0] num1_term_1 =
        {prod_b2_a12[PROD_WIDTH-1], prod_b2_a12};

    wire signed [DIFF_WIDTH-1:0] num2_term_0 =
        {prod_a11_b2[PROD_WIDTH-1], prod_a11_b2};
    wire signed [DIFF_WIDTH-1:0] num2_term_1 =
        {prod_a21_b1[PROD_WIDTH-1], prod_a21_b1};

    wire signed [DIFF_WIDTH-1:0] det  = det_term_0  - det_term_1;
    wire signed [DIFF_WIDTH-1:0] num1 = num1_term_0 - num1_term_1;
    wire signed [DIFF_WIDTH-1:0] num2 = num2_term_0 - num2_term_1;

    wire det_zero = (det == {DIFF_WIDTH{1'b0}});

    wire signed [DIV_WIDTH-1:0] det_ext =
        {{(DIV_WIDTH-DIFF_WIDTH){det[DIFF_WIDTH-1]}}, det};

    wire signed [DIV_WIDTH-1:0] det_safe =
        det_zero ? {{(DIV_WIDTH-1){1'b0}}, 1'b1} : det_ext;

    wire signed [DIV_WIDTH-1:0] num1_ext =
        {{(DIV_WIDTH-DIFF_WIDTH){num1[DIFF_WIDTH-1]}}, num1};
    wire signed [DIV_WIDTH-1:0] num2_ext =
        {{(DIV_WIDTH-DIFF_WIDTH){num2[DIFF_WIDTH-1]}}, num2};

    wire signed [DIV_WIDTH-1:0] dividend1 = num1_ext <<< FRAC;
    wire signed [DIV_WIDTH-1:0] dividend2 = num2_ext <<< FRAC;

    wire signed [DIV_WIDTH-1:0] quotient1 = dividend1 / det_safe;
    wire signed [DIV_WIDTH-1:0] quotient2 = dividend2 / det_safe;

    function signed [DATA_WIDTH-1:0] saturate_to_data_width;
        input signed [DIV_WIDTH-1:0] value;
        reg   signed [DIV_WIDTH-1:0] max_value;
        reg   signed [DIV_WIDTH-1:0] min_value;
        begin
            max_value = {{(DIV_WIDTH-DATA_WIDTH){1'b0}},
                         1'b0, {DATA_WIDTH-1{1'b1}}};
            min_value = {{(DIV_WIDTH-DATA_WIDTH){1'b1}},
                         1'b1, {DATA_WIDTH-1{1'b0}}};

            if (value > max_value)
                saturate_to_data_width = {1'b0, {DATA_WIDTH-1{1'b1}}};
            else if (value < min_value)
                saturate_to_data_width = {1'b1, {DATA_WIDTH-1{1'b0}}};
            else
                saturate_to_data_width = value[DATA_WIDTH-1:0];
        end
    endfunction

    assign x1_direct = det_zero ? {DATA_WIDTH{1'b0}} : saturate_to_data_width(quotient1);
    assign x2_direct = det_zero ? {DATA_WIDTH{1'b0}} : saturate_to_data_width(quotient2);

endmodule