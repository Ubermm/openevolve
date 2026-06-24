`timescale 1ns/1ps

module fft_butterfly_fixed #(
    parameter DATA_W  = 16,
    parameter COEFF_W = 16
) (
    input mode, // 0: FFT, 1: IFFT
    input signed [DATA_W-1:0]  a_real,
    input signed [DATA_W-1:0]  a_imag,
    input signed [DATA_W-1:0]  b_real,
    input signed [DATA_W-1:0]  b_imag,
    input signed [COEFF_W-1:0] tw_cos,
    input signed [COEFF_W-1:0] tw_sin,
    output signed [DATA_W-1:0] y0_real,
    output signed [DATA_W-1:0] y0_imag,
    output signed [DATA_W-1:0] y1_real,
    output signed [DATA_W-1:0] y1_imag
);

    localparam integer PROD_W = DATA_W + COEFF_W;
    localparam integer ACC_W  = PROD_W + 2;
    localparam integer Q_FRAC = COEFF_W - 1;

    wire signed [PROD_W-1:0] br_cos_prod = b_real * tw_cos;
    wire signed [PROD_W-1:0] bi_sin_prod = b_imag * tw_sin;
    wire signed [PROD_W-1:0] bi_cos_prod = b_imag * tw_cos;
    wire signed [PROD_W-1:0] br_sin_prod = b_real * tw_sin;

    wire signed [ACC_W-1:0] br_cos_ext =
        {{(ACC_W-PROD_W){br_cos_prod[PROD_W-1]}}, br_cos_prod};
    wire signed [ACC_W-1:0] bi_sin_ext =
        {{(ACC_W-PROD_W){bi_sin_prod[PROD_W-1]}}, bi_sin_prod};
    wire signed [ACC_W-1:0] bi_cos_ext =
        {{(ACC_W-PROD_W){bi_cos_prod[PROD_W-1]}}, bi_cos_prod};
    wire signed [ACC_W-1:0] br_sin_ext =
        {{(ACC_W-PROD_W){br_sin_prod[PROD_W-1]}}, br_sin_prod};

    wire signed [ACC_W-1:0] round_const =
        {{(ACC_W-COEFF_W+1){1'b0}}, 1'b1, {(COEFF_W-2){1'b0}}};

    /*
        FFT mode:
            (b_real + j*b_imag) * (cos - j*sin)
            tr_real = b_real*cos + b_imag*sin
            tr_imag = b_imag*cos - b_real*sin

        IFFT mode:
            (b_real + j*b_imag) * (cos + j*sin)
            tr_real = b_real*cos - b_imag*sin
            tr_imag = b_imag*cos + b_real*sin
    */
    wire signed [ACC_W-1:0] tr_real_acc =
        mode ? (br_cos_ext - bi_sin_ext) : (br_cos_ext + bi_sin_ext);

    wire signed [ACC_W-1:0] tr_imag_acc =
        mode ? (bi_cos_ext + br_sin_ext) : (bi_cos_ext - br_sin_ext);

    wire signed [ACC_W-1:0] tr_real_shifted = (tr_real_acc + round_const) >>> Q_FRAC;
    wire signed [ACC_W-1:0] tr_imag_shifted = (tr_imag_acc + round_const) >>> Q_FRAC;

    wire signed [DATA_W-1:0] tr_real = tr_real_shifted[DATA_W-1:0];
    wire signed [DATA_W-1:0] tr_imag = tr_imag_shifted[DATA_W-1:0];

    assign y0_real = a_real + tr_real;
    assign y0_imag = a_imag + tr_imag;
    assign y1_real = a_real - tr_real;
    assign y1_imag = a_imag - tr_imag;

endmodule