`timescale 1ns/1ps

module fft_radix2_butterfly #(
    parameter W = 20
) (
    input  signed [W-1:0] a_real,
    input  signed [W-1:0] a_imag,
    input  signed [W-1:0] b_real,
    input  signed [W-1:0] b_imag,
    output signed [W-1:0] y0_real,
    output signed [W-1:0] y0_imag,
    output signed [W-1:0] y1_real,
    output signed [W-1:0] y1_imag
);

    /*
     * Radix-2 butterfly:
     *
     *   y0 = a + b
     *   y1 = a - b
     *
     * Operands are explicitly sign-extended by one bit before arithmetic.
     * The final assignment returns the low W bits, matching normal W-bit
     * two's-complement hardware behavior while avoiding expression-width
     * ambiguity.
     */

    wire signed [W:0] a_real_ext = {a_real[W-1], a_real};
    wire signed [W:0] a_imag_ext = {a_imag[W-1], a_imag};
    wire signed [W:0] b_real_ext = {b_real[W-1], b_real};
    wire signed [W:0] b_imag_ext = {b_imag[W-1], b_imag};

    wire signed [W:0] sum_real  = a_real_ext + b_real_ext;
    wire signed [W:0] sum_imag  = a_imag_ext + b_imag_ext;
    wire signed [W:0] diff_real = a_real_ext - b_real_ext;
    wire signed [W:0] diff_imag = a_imag_ext - b_imag_ext;

    assign y0_real = sum_real[W-1:0];
    assign y0_imag = sum_imag[W-1:0];
    assign y1_real = diff_real[W-1:0];
    assign y1_imag = diff_imag[W-1:0];

endmodule