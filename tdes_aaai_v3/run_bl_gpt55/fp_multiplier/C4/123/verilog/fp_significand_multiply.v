`timescale 1ns/1ps

module fp_significand_multiply #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23
)(
    input  sign_a,
    input  sign_b,
    input  [MANT_WIDTH:0] sig_a,
    input  [MANT_WIDTH:0] sig_b,
    input  signed [EXP_WIDTH+1:0] exp_a_unbiased,
    input  signed [EXP_WIDTH+1:0] exp_b_unbiased,
    output reg result_sign,
    output reg signed [EXP_WIDTH+2:0] exp_sum_unbiased,
    output reg [2*(MANT_WIDTH+1)-1:0] raw_product
);

    localparam EXP_IN_WIDTH  = EXP_WIDTH + 2;
    localparam EXP_OUT_WIDTH = EXP_WIDTH + 3;
    localparam SIG_WIDTH     = MANT_WIDTH + 1;
    localparam PROD_WIDTH    = 2 * SIG_WIDTH;

    wire signed [EXP_OUT_WIDTH-1:0] exp_a_ext;
    wire signed [EXP_OUT_WIDTH-1:0] exp_b_ext;

    wire [PROD_WIDTH-1:0] sig_a_ext;
    wire [PROD_WIDTH-1:0] sig_b_ext;
    wire [PROD_WIDTH-1:0] product_full_width;

    assign exp_a_ext = {{(EXP_OUT_WIDTH-EXP_IN_WIDTH){exp_a_unbiased[EXP_IN_WIDTH-1]}}, exp_a_unbiased};
    assign exp_b_ext = {{(EXP_OUT_WIDTH-EXP_IN_WIDTH){exp_b_unbiased[EXP_IN_WIDTH-1]}}, exp_b_unbiased};

    /*
     * Extend the operands before multiplication.
     * In Verilog, the width of a multiplication expression can otherwise be
     * limited by the operand widths, which would truncate the upper half of
     * the significand product before assignment to raw_product.
     */
    assign sig_a_ext = {{SIG_WIDTH{1'b0}}, sig_a};
    assign sig_b_ext = {{SIG_WIDTH{1'b0}}, sig_b};
    assign product_full_width = sig_a_ext * sig_b_ext;

    always @* begin
        result_sign        = sign_a ^ sign_b;
        exp_sum_unbiased   = exp_a_ext + exp_b_ext;
        raw_product        = product_full_width;
    end

endmodule