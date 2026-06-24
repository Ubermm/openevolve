`timescale 1ns/1ps

module fft64_complex_mult #(
    parameter W    = 20,
    parameter TW_W = 16
) (
    input  signed [W-1:0]    a_re,
    input  signed [W-1:0]    a_im,
    input  signed [TW_W-1:0] b_re,
    input  signed [TW_W-1:0] b_im,
    output signed [W-1:0]    p_re,
    output signed [W-1:0]    p_im
);

    /*
     * Twiddle factors are Q1.(TW_W-1).
     * For the default TW_W=16 this is Q1.15, so the complex product
     * must be arithmetically shifted right by 15 bits.
     */
    localparam FRAC_W = TW_W - 1;

    /*
     * Product width for signed W x TW_W multiplication.
     * One additional guard bit is needed for add/subtract of two products.
     */
    localparam PROD_W = W + TW_W;
    localparam ACC_W  = PROD_W + 1;

    wire signed [PROD_W-1:0] ac_prod;
    wire signed [PROD_W-1:0] bd_prod;
    wire signed [PROD_W-1:0] ad_prod;
    wire signed [PROD_W-1:0] bc_prod;

    assign ac_prod = a_re * b_re;
    assign bd_prod = a_im * b_im;
    assign ad_prod = a_re * b_im;
    assign bc_prod = a_im * b_re;

    /*
     * Explicit sign extension before the complex add/subtract step.
     */
    wire signed [ACC_W-1:0] ac_ext;
    wire signed [ACC_W-1:0] bd_ext;
    wire signed [ACC_W-1:0] ad_ext;
    wire signed [ACC_W-1:0] bc_ext;

    assign ac_ext = {ac_prod[PROD_W-1], ac_prod};
    assign bd_ext = {bd_prod[PROD_W-1], bd_prod};
    assign ad_ext = {ad_prod[PROD_W-1], ad_prod};
    assign bc_ext = {bc_prod[PROD_W-1], bc_prod};

    wire signed [ACC_W-1:0] real_full;
    wire signed [ACC_W-1:0] imag_full;

    assign real_full = ac_ext - bd_ext;
    assign imag_full = ad_ext + bc_ext;

    wire signed [ACC_W-1:0] real_scaled;
    wire signed [ACC_W-1:0] imag_scaled;

    assign real_scaled = real_full >>> FRAC_W;
    assign imag_scaled = imag_full >>> FRAC_W;

    /*
     * Keep the low W bits after scaling.
     * This preserves normal two's-complement wrap/truncation behavior.
     */
    assign p_re = real_scaled[W-1:0];
    assign p_im = imag_scaled[W-1:0];

endmodule