module fft16_butterfly #(
    parameter X_W = 16,
    parameter COEFF_W = 16
) (
    input mode, // 0: FFT, 1: IFFT
    input signed [X_W-1:0] a_real,
    input signed [X_W-1:0] a_imag,
    input signed [X_W-1:0] b_real,
    input signed [X_W-1:0] b_imag,
    input signed [COEFF_W-1:0] tw_cos,
    input signed [COEFF_W-1:0] tw_sin,
    output signed [X_W-1:0] y0_real,
    output signed [X_W-1:0] y0_imag,
    output signed [X_W-1:0] y1_real,
    output signed [X_W-1:0] y1_imag
);

    localparam PROD_W = X_W + COEFF_W + 1;
    localparam ACC_W  = PROD_W + 2;
    localparam SHIFT  = COEFF_W - 1;

    wire signed [COEFF_W:0] cos_ext;
    wire signed [COEFF_W:0] sin_ext;
    wire signed [COEFF_W:0] sin_eff;

    assign cos_ext = {tw_cos[COEFF_W-1], tw_cos};
    assign sin_ext = {tw_sin[COEFF_W-1], tw_sin};

    // FFT : W = cos - j*sin  -> use +sin in real term, -sin in imag term
    // IFFT: W = cos + j*sin  -> conjugate by negating the sine component
    assign sin_eff = mode ? -sin_ext : sin_ext;

    wire signed [PROD_W-1:0] prod_br_cos;
    wire signed [PROD_W-1:0] prod_bi_sin;
    wire signed [PROD_W-1:0] prod_bi_cos;
    wire signed [PROD_W-1:0] prod_br_sin;

    assign prod_br_cos = b_real * cos_ext;
    assign prod_bi_sin = b_imag * sin_eff;
    assign prod_bi_cos = b_imag * cos_ext;
    assign prod_br_sin = b_real * sin_eff;

    wire signed [ACC_W-1:0] prod_br_cos_ext;
    wire signed [ACC_W-1:0] prod_bi_sin_ext;
    wire signed [ACC_W-1:0] prod_bi_cos_ext;
    wire signed [ACC_W-1:0] prod_br_sin_ext;

    assign prod_br_cos_ext = {{(ACC_W-PROD_W){prod_br_cos[PROD_W-1]}}, prod_br_cos};
    assign prod_bi_sin_ext = {{(ACC_W-PROD_W){prod_bi_sin[PROD_W-1]}}, prod_bi_sin};
    assign prod_bi_cos_ext = {{(ACC_W-PROD_W){prod_bi_cos[PROD_W-1]}}, prod_bi_cos};
    assign prod_br_sin_ext = {{(ACC_W-PROD_W){prod_br_sin[PROD_W-1]}}, prod_br_sin};

    wire signed [ACC_W-1:0] mult_real_acc;
    wire signed [ACC_W-1:0] mult_imag_acc;

    assign mult_real_acc = prod_br_cos_ext + prod_bi_sin_ext;
    assign mult_imag_acc = prod_bi_cos_ext - prod_br_sin_ext;

    wire signed [ACC_W-1:0] round_const;
    assign round_const = ($signed({{(ACC_W-1){1'b0}}, 1'b1}) <<< (COEFF_W-2));

    wire signed [ACC_W-1:0] tr_real_wide;
    wire signed [ACC_W-1:0] tr_imag_wide;

    assign tr_real_wide = (mult_real_acc + round_const) >>> SHIFT;
    assign tr_imag_wide = (mult_imag_acc + round_const) >>> SHIFT;

    wire signed [X_W-1:0] tr_real;
    wire signed [X_W-1:0] tr_imag;

    assign tr_real = tr_real_wide[X_W-1:0];
    assign tr_imag = tr_imag_wide[X_W-1:0];

    assign y0_real = a_real + tr_real;
    assign y0_imag = a_imag + tr_imag;
    assign y1_real = a_real - tr_real;
    assign y1_imag = a_imag - tr_imag;

endmodule