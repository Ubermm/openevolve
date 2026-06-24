module butterfly #(
    parameter IN_W    = 12,
    parameter COEFF_W = 16
) (
    input  signed [IN_W-1:0]    xr,
    input  signed [IN_W-1:0]    xi,
    input  signed [IN_W-1:0]    yr,
    input  signed [IN_W-1:0]    yi,
    input  signed [COEFF_W-1:0] cos_w,
    input  signed [COEFF_W-1:0] sin_w,
    input                       mode,    // 0: FFT, 1: IFFT
    output signed [IN_W:0]      p_r,     // sum real
    output signed [IN_W:0]      p_i,     // sum imag
    output signed [IN_W:0]      q_r,     // diff real
    output signed [IN_W:0]      q_i      // diff imag
);

    // number of fractional bits in Q1.(COEFF_W-1)
    localparam integer FRAC = COEFF_W - 1;
    // rounding constant = 2^(FRAC-1)
    localparam signed [FRAC:0] ROUND = 1 <<< (FRAC-1);

    // full precision twiddle multiplies (INT * Q1.FRAC -> Q1.FRAC)
    wire signed [IN_W+COEFF_W-1:0] yr_cos = yr * cos_w;
    wire signed [IN_W+COEFF_W-1:0] yi_sin = yi * sin_w;
    wire signed [IN_W+COEFF_W-1:0] yi_cos = yi * cos_w;
    wire signed [IN_W+COEFF_W-1:0] yr_sin = yr * sin_w;

    // FFT mode (e^{-j2pi k/N} = cos - j*sin)
    wire signed [IN_W+COEFF_W-1:0] sum_r_fft = yr_cos + yi_sin;
    wire signed [IN_W+COEFF_W-1:0] sum_i_fft = yi_cos - yr_sin;
    // IFFT mode (conjugate twiddle cos + j*sin)
    wire signed [IN_W+COEFF_W-1:0] sum_r_ifft = yr_cos - yi_sin;
    wire signed [IN_W+COEFF_W-1:0] sum_i_ifft = yi_cos + yr_sin;

    // select pre-rounded twiddle result
    wire signed [IN_W+COEFF_W-1:0] tw_r_pre = mode ? sum_r_ifft : sum_r_fft;
    wire signed [IN_W+COEFF_W-1:0] tw_i_pre = mode ? sum_i_ifft : sum_i_fft;

    // apply rounding constant (always +ROUND per spec) and shift back to integer
    wire signed [IN_W:0] rot_r = (tw_r_pre + ROUND) >>> FRAC;
    wire signed [IN_W:0] rot_i = (tw_i_pre + ROUND) >>> FRAC;

    // butterfly sum/difference
    assign p_r = xr + rot_r;
    assign p_i = xi + rot_i;
    assign q_r = xr - rot_r;
    assign q_i = xi - rot_i;

endmodule