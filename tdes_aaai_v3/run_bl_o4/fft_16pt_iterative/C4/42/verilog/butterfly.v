module butterfly #(
    parameter DATA_W  = 12,
    parameter GAIN_W  = 4,
    parameter COEFF_W = 16
) (
    input  signed [DATA_W+GAIN_W-1:0] p_re,
    input  signed [DATA_W+GAIN_W-1:0] p_im,
    input  signed [DATA_W+GAIN_W-1:0] q_re,
    input  signed [DATA_W+GAIN_W-1:0] q_im,
    input  signed [COEFF_W-1:0]       tw_re,
    input  signed [COEFF_W-1:0]       tw_im,
    input                              mode,      // 0: FFT, 1: IFFT
    output signed [DATA_W+GAIN_W-1:0] out_p_re,
    output signed [DATA_W+GAIN_W-1:0] out_p_im,
    output signed [DATA_W+GAIN_W-1:0] out_q_re,
    output signed [DATA_W+GAIN_W-1:0] out_q_im
);

    // Select twiddle imaginary sign: FFT uses -sin, IFFT uses +sin
    wire signed [COEFF_W-1:0] tw_im_calc = mode ? tw_im : -tw_im;

    // 16x16 multiplies -> 32 bit results
    wire signed [31:0] mul_qre_tr = q_re   * tw_re;
    wire signed [31:0] mul_qim_ti = q_im   * tw_im_calc;
    wire signed [31:0] mul_qim_tr = q_im   * tw_re;
    wire signed [31:0] mul_qre_ti = q_re   * tw_im_calc;

    // Sum and difference with rounding bias (2^14)
    wire signed [32:0] sum_re      = mul_qre_tr + mul_qim_ti;
    wire signed [32:0] sum_im      = mul_qim_tr - mul_qre_ti;
    wire signed [32:0] sum_re_rnd  = sum_re + 33'sd16384;
    wire signed [32:0] sum_im_rnd  = sum_im + 33'sd16384;

    // Extract rotated values (Q1.15 -> integer)
    wire signed [DATA_W+GAIN_W-1:0] t_re = sum_re_rnd[32:15];
    wire signed [DATA_W+GAIN_W-1:0] t_im = sum_im_rnd[32:15];

    // Butterfly combine: p plus rotated, q minus rotated
    wire signed [DATA_W+GAIN_W-1:0] p_plus_re  = p_re + t_re;
    wire signed [DATA_W+GAIN_W-1:0] p_plus_im  = p_im + t_im;
    wire signed [DATA_W+GAIN_W-1:0] q_minus_re = p_re - t_re;
    wire signed [DATA_W+GAIN_W-1:0] q_minus_im = p_im - t_im;

    // Scale down by 16 for IFFT (arithmetic shift preserves sign)
    assign out_p_re = mode ? (p_plus_re  >>> GAIN_W) : p_plus_re;
    assign out_p_im = mode ? (p_plus_im  >>> GAIN_W) : p_plus_im;
    assign out_q_re = mode ? (q_minus_re >>> GAIN_W) : q_minus_re;
    assign out_q_im = mode ? (q_minus_im >>> GAIN_W) : q_minus_im;

endmodule