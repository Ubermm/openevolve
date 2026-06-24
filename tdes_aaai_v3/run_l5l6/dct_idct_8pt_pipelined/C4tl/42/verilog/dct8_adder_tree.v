`timescale 1ns/1ps

module dct8_adder_tree #(
    parameter PROD_W = 28,
    parameter SUM_W  = 32
) (
    input  signed [PROD_W-1:0] p0,
    input  signed [PROD_W-1:0] p1,
    input  signed [PROD_W-1:0] p2,
    input  signed [PROD_W-1:0] p3,
    input  signed [PROD_W-1:0] p4,
    input  signed [PROD_W-1:0] p5,
    input  signed [PROD_W-1:0] p6,
    input  signed [PROD_W-1:0] p7,
    output signed [SUM_W-1:0]  sum_out
);

    /*
     * Sign-extend each product to the accumulator width before adding.
     * Keeping all intermediate sums at SUM_W avoids accidental unsigned
     * arithmetic or narrow-width truncation during the adder tree.
     */
    function signed [SUM_W-1:0] sign_extend_prod;
        input signed [PROD_W-1:0] value;
        begin
            sign_extend_prod = value;
        end
    endfunction

    wire signed [SUM_W-1:0] e0;
    wire signed [SUM_W-1:0] e1;
    wire signed [SUM_W-1:0] e2;
    wire signed [SUM_W-1:0] e3;
    wire signed [SUM_W-1:0] e4;
    wire signed [SUM_W-1:0] e5;
    wire signed [SUM_W-1:0] e6;
    wire signed [SUM_W-1:0] e7;

    assign e0 = sign_extend_prod(p0);
    assign e1 = sign_extend_prod(p1);
    assign e2 = sign_extend_prod(p2);
    assign e3 = sign_extend_prod(p3);
    assign e4 = sign_extend_prod(p4);
    assign e5 = sign_extend_prod(p5);
    assign e6 = sign_extend_prod(p6);
    assign e7 = sign_extend_prod(p7);

    wire signed [SUM_W-1:0] s01;
    wire signed [SUM_W-1:0] s23;
    wire signed [SUM_W-1:0] s45;
    wire signed [SUM_W-1:0] s67;

    wire signed [SUM_W-1:0] s03;
    wire signed [SUM_W-1:0] s47;

    assign s01 = e0 + e1;
    assign s23 = e2 + e3;
    assign s45 = e4 + e5;
    assign s67 = e6 + e7;

    assign s03 = s01 + s23;
    assign s47 = s45 + s67;

    assign sum_out = s03 + s47;

endmodule