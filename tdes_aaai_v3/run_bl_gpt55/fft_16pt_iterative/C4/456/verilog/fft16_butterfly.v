`timescale 1ns/1ps

module fft16_butterfly #(
    parameter DATA_W  = 12,
    parameter COEFF_W = 16,
    parameter GAIN_W  = 4
) (
    input mode,
    input signed [DATA_W+GAIN_W-1:0] x0_real,
    input signed [DATA_W+GAIN_W-1:0] x0_imag,
    input signed [DATA_W+GAIN_W-1:0] x1_real,
    input signed [DATA_W+GAIN_W-1:0] x1_imag,
    input signed [COEFF_W-1:0] cos_q15,
    input signed [COEFF_W-1:0] sin_q15,
    output signed [DATA_W+GAIN_W-1:0] y0_real,
    output signed [DATA_W+GAIN_W-1:0] y0_imag,
    output signed [DATA_W+GAIN_W-1:0] y1_real,
    output signed [DATA_W+GAIN_W-1:0] y1_imag
);

    localparam OUT_W       = DATA_W + GAIN_W;
    localparam COEFF_EXT_W = COEFF_W + 1;
    localparam PROD_W      = OUT_W + COEFF_EXT_W;
    localparam ACC_W       = PROD_W + 1;
    localparam Q_FRAC      = COEFF_W - 1;

    wire signed [COEFF_EXT_W-1:0] cos_ext;
    wire signed [COEFF_EXT_W-1:0] sin_ext;
    wire signed [COEFF_EXT_W-1:0] sin_eff;

    assign cos_ext = {cos_q15[COEFF_W-1], cos_q15};
    assign sin_ext = {sin_q15[COEFF_W-1], sin_q15};

    /*
     * mode = 0: FFT  twiddle = cos - j*sin
     * mode = 1: IFFT twiddle = cos + j*sin
     *
     * The datapath below uses:
     *   tr_real = xr*cos + xi*sin_eff
     *   tr_imag = xi*cos - xr*sin_eff
     * Therefore sin_eff is negated for IFFT.
     */
    assign sin_eff = mode ? -sin_ext : sin_ext;

    wire signed [PROD_W-1:0] xr_cos;
    wire signed [PROD_W-1:0] xi_sin;
    wire signed [PROD_W-1:0] xi_cos;
    wire signed [PROD_W-1:0] xr_sin;

    assign xr_cos = x1_real * cos_ext;
    assign xi_sin = x1_imag * sin_eff;
    assign xi_cos = x1_imag * cos_ext;
    assign xr_sin = x1_real * sin_eff;

    wire signed [ACC_W-1:0] mult_real_sum;
    wire signed [ACC_W-1:0] mult_imag_sum;

    assign mult_real_sum = {xr_cos[PROD_W-1], xr_cos} + {xi_sin[PROD_W-1], xi_sin};
    assign mult_imag_sum = {xi_cos[PROD_W-1], xi_cos} - {xr_sin[PROD_W-1], xr_sin};

    wire signed [ACC_W-1:0] round_const;
    assign round_const = {{(ACC_W-1){1'b0}}, 1'b1} <<< (Q_FRAC - 1);

    wire signed [ACC_W-1:0] tr_real_ext;
    wire signed [ACC_W-1:0] tr_imag_ext;

    assign tr_real_ext = (mult_real_sum + round_const) >>> Q_FRAC;
    assign tr_imag_ext = (mult_imag_sum + round_const) >>> Q_FRAC;

    wire signed [ACC_W-1:0] x0_real_ext;
    wire signed [ACC_W-1:0] x0_imag_ext;

    assign x0_real_ext = {{(ACC_W-OUT_W){x0_real[OUT_W-1]}}, x0_real};
    assign x0_imag_ext = {{(ACC_W-OUT_W){x0_imag[OUT_W-1]}}, x0_imag};

    wire signed [ACC_W-1:0] y0_real_ext;
    wire signed [ACC_W-1:0] y0_imag_ext;
    wire signed [ACC_W-1:0] y1_real_ext;
    wire signed [ACC_W-1:0] y1_imag_ext;

    assign y0_real_ext = x0_real_ext + tr_real_ext;
    assign y0_imag_ext = x0_imag_ext + tr_imag_ext;
    assign y1_real_ext = x0_real_ext - tr_real_ext;
    assign y1_imag_ext = x0_imag_ext - tr_imag_ext;

    assign y0_real = y0_real_ext[OUT_W-1:0];
    assign y0_imag = y0_imag_ext[OUT_W-1:0];
    assign y1_real = y1_real_ext[OUT_W-1:0];
    assign y1_imag = y1_imag_ext[OUT_W-1:0];

endmodule