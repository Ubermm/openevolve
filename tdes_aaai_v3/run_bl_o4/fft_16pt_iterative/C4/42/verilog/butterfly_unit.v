module butterfly_unit #(
    parameter integer DATA_W  = 12,
    parameter integer COEFF_W = 16,
    parameter integer GAIN_W  = 4
) (
    input                          mode,    // 0: FFT, 1: IFFT
    input  signed [DATA_W+GAIN_W-1:0] xr_p,
    input  signed [DATA_W+GAIN_W-1:0] xi_p,
    input  signed [DATA_W+GAIN_W-1:0] xr_q,
    input  signed [DATA_W+GAIN_W-1:0] xi_q,
    input  signed [COEFF_W-1:0]       cos_q,
    input  signed [COEFF_W-1:0]       sin_q,
    output signed [DATA_W+GAIN_W-1:0] yr_p,
    output signed [DATA_W+GAIN_W-1:0] yi_p,
    output signed [DATA_W+GAIN_W-1:0] yr_q,
    output signed [DATA_W+GAIN_W-1:0] yi_q
);

    // number of fractional bits in twiddle (Q1.15)
    localparam integer FRAC_BITS = COEFF_W - 1;
    // rounding constant for Q1.15 multiply
    localparam integer ROUND = 1 << (FRAC_BITS-1);
    // full product width = DATA_W+GAIN_W + COEFF_W
    localparam integer PROD_W = DATA_W + GAIN_W + COEFF_W;

    // effective sine: for FFT (mode=0) use +sin, for IFFT (mode=1) use -sin (conjugation)
    wire signed [COEFF_W-1:0] sin_eff = mode ? -sin_q : sin_q;

    // complex multiply xq * W
    wire signed [PROD_W-1:0] mul_xr_cos = xr_q * cos_q;
    wire signed [PROD_W-1:0] mul_xi_sin = xi_q * sin_eff;
    wire signed [PROD_W-1:0] mul_xi_cos = xi_q * cos_q;
    wire signed [PROD_W-1:0] mul_xr_sin = xr_q * sin_eff;

    // accumulate terms with one-bit extra for rounding
    wire signed [PROD_W:0] acc_real = mul_xr_cos + mul_xi_sin;  // xr*cos + xi*sin
    wire signed [PROD_W:0] acc_imag = mul_xi_cos - mul_xr_sin;  // xi*cos - xr*sin

    // add rounding offset
    wire signed [PROD_W:0] acc_real_r = acc_real + ROUND;
    wire signed [PROD_W:0] acc_imag_r = acc_imag + ROUND;

    // shift down fractional bits to align Q-format, result is DATA_W+GAIN_W bits
    wire signed [DATA_W+GAIN_W-1:0] tr_real = acc_real_r >>> FRAC_BITS;
    wire signed [DATA_W+GAIN_W-1:0] tr_imag = acc_imag_r >>> FRAC_BITS;

    // butterfly combine: p = x_p + twiddled x_q; q = x_p - twiddled x_q
    assign yr_p = xr_p + tr_real;
    assign yi_p = xi_p + tr_imag;
    assign yr_q = xr_p - tr_real;
    assign yi_q = xi_p - tr_imag;

endmodule