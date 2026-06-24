`timescale 1ns/1ps

module fft_complex_mult_q15 #(
    parameter A_W    = 20,
    parameter TW_W   = 16,
    parameter OUT_W  = 20,
    parameter FRAC_W = 15
) (
    input  signed [A_W-1:0]   a_real,
    input  signed [A_W-1:0]   a_imag,
    input  signed [TW_W-1:0]  b_real,
    input  signed [TW_W-1:0]  b_imag,
    output signed [OUT_W-1:0] p_real,
    output signed [OUT_W-1:0] p_imag
);

    localparam PROD_W = A_W + TW_W;
    localparam ACC_W  = PROD_W + 1;

    wire signed [PROD_W-1:0] mult_rr = a_real * b_real;
    wire signed [PROD_W-1:0] mult_ii = a_imag * b_imag;
    wire signed [PROD_W-1:0] mult_ri = a_real * b_imag;
    wire signed [PROD_W-1:0] mult_ir = a_imag * b_real;

    /*
     * Sign-extend before addition/subtraction.
     *
     * In Verilog, the width of "mult_rr - mult_ii" would otherwise be only
     * PROD_W bits, even if assigned into a wider destination.  The complex
     * multiply sum/difference of two PROD_W-bit products requires ACC_W bits.
     */
    wire signed [ACC_W-1:0] mult_rr_ext = {mult_rr[PROD_W-1], mult_rr};
    wire signed [ACC_W-1:0] mult_ii_ext = {mult_ii[PROD_W-1], mult_ii};
    wire signed [ACC_W-1:0] mult_ri_ext = {mult_ri[PROD_W-1], mult_ri};
    wire signed [ACC_W-1:0] mult_ir_ext = {mult_ir[PROD_W-1], mult_ir};

    wire signed [ACC_W-1:0] real_full = mult_rr_ext - mult_ii_ext;
    wire signed [ACC_W-1:0] imag_full = mult_ri_ext + mult_ir_ext;

    wire signed [ACC_W-1:0] real_scaled = real_full >>> FRAC_W;
    wire signed [ACC_W-1:0] imag_scaled = imag_full >>> FRAC_W;

    assign p_real = real_scaled;
    assign p_imag = imag_scaled;

endmodule