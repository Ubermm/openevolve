module butterfly #(
    parameter integer OUT_W   = 16,
    parameter integer COEFF_W = 16
)(
    input  wire                   mode,      // 0: FFT, 1: IFFT
    input  wire signed [OUT_W-1:0] a_re,
    input  wire signed [OUT_W-1:0] a_im,
    input  wire signed [OUT_W-1:0] b_re,
    input  wire signed [OUT_W-1:0] b_im,
    input  wire signed [COEFF_W-1:0] cos_q15,
    input  wire signed [COEFF_W-1:0] sin_q15,
    output wire signed [OUT_W-1:0] y0_re,
    output wire signed [OUT_W-1:0] y0_im,
    output wire signed [OUT_W-1:0] y1_re,
    output wire signed [OUT_W-1:0] y1_im
);
    // Q1.15 fractional bits
    localparam integer FRAC  = COEFF_W - 1;
    // Rounding constant for Q1.15
    localparam integer ROUND = 1 << (FRAC - 1);

    // Raw products
    wire signed [OUT_W+COEFF_W-1:0] mul_cr = b_re * cos_q15;
    wire signed [OUT_W+COEFF_W-1:0] mul_sr = b_re * sin_q15;
    wire signed [OUT_W+COEFF_W-1:0] mul_ic = b_im * cos_q15;
    wire signed [OUT_W+COEFF_W-1:0] mul_is = b_im * sin_q15;

    // Twiddle multiply with rounding and FFT/IFFT selection
    // FFT (mode=0): W = cos - j*sin
    // IFFT(mode=1): W = cos + j*sin
    wire signed [OUT_W+COEFF_W:0] sum_re = mode
        ? (mul_cr - mul_is + ROUND)  // IFFT: b_re*cos - b_im*sin
        : (mul_cr + mul_is + ROUND); // FFT:  b_re*cos + b_im*sin

    wire signed [OUT_W+COEFF_W:0] sum_im = mode
        ? (mul_ic + mul_sr + ROUND)  // IFFT: b_im*cos + b_re*sin
        : (mul_ic - mul_sr + ROUND); // FFT:  b_im*cos - b_re*sin

    // Extract rounded Q1.15 results
    wire signed [OUT_W-1:0] tr_re = sum_re[FRAC+OUT_W-1:FRAC];
    wire signed [OUT_W-1:0] tr_im = sum_im[FRAC+OUT_W-1:FRAC];

    // Butterfly sum/difference
    wire signed [OUT_W-1:0] add_re = a_re + tr_re;
    wire signed [OUT_W-1:0] add_im = a_im + tr_im;
    wire signed [OUT_W-1:0] sub_re = a_re - tr_re;
    wire signed [OUT_W-1:0] sub_im = a_im - tr_im;

    // Output assignments with optional IFFT normalization (/16 => >>4)
    assign y0_re = mode ? (add_re >>> 4) : add_re;
    assign y0_im = mode ? (add_im >>> 4) : add_im;
    assign y1_re = mode ? (sub_re >>> 4) : sub_re;
    assign y1_im = mode ? (sub_im >>> 4) : sub_im;

endmodule