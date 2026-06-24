module fft_butterfly #(
    parameter WID     = 16,
    parameter COEFF_W = 16
) (
    input  signed [WID-1:0]     x0_re,
    input  signed [WID-1:0]     x0_im,
    input  signed [WID-1:0]     x1_re,
    input  signed [WID-1:0]     x1_im,
    input  signed [COEFF_W-1:0] tw_cos,
    input  signed [COEFF_W-1:0] tw_sin,
    output signed [WID:0]       y0_re,
    output signed [WID:0]       y0_im,
    output signed [WID:0]       y1_re,
    output signed [WID:0]       y1_im
);
    // internal widths
    localparam MUL_IW  = WID + COEFF_W;    // product integer width
    localparam SUM_IW  = MUL_IW + 1;       // widen for addition
    localparam FRACT   = COEFF_W - 1;      // fractional bits in product

    // multiply terms
    wire signed [MUL_IW-1:0] mul_re_cos = x1_re * tw_cos;
    wire signed [MUL_IW-1:0] mul_im_sin = x1_im * tw_sin;
    wire signed [MUL_IW-1:0] mul_im_cos = x1_im * tw_cos;
    wire signed [MUL_IW-1:0] mul_re_sin = x1_re * tw_sin;

    // real part: x1_re*cos + x1_im*sin
    wire signed [SUM_IW-1:0] sum_re     = {{1{mul_re_cos[MUL_IW-1]}}, mul_re_cos}
                                      + {{1{mul_im_sin[MUL_IW-1]}}, mul_im_sin};
    wire signed [SUM_IW-1:0] sum_re_rnd = sum_re + (1 << (FRACT-1));
    wire signed [WID-1:0]    tr_re      = sum_re_rnd[MUL_IW-2:FRACT];

    // imag part: x1_im*cos - x1_re*sin
    wire signed [SUM_IW-1:0] sum_im     = {{1{mul_im_cos[MUL_IW-1]}}, mul_im_cos}
                                      - {{1{mul_re_sin[MUL_IW-1]}}, mul_re_sin};
    wire signed [SUM_IW-1:0] sum_im_rnd = sum_im + (1 << (FRACT-1));
    wire signed [WID-1:0]    tr_im      = sum_im_rnd[MUL_IW-2:FRACT];

    // butterfly outputs (one bit growth)
    assign y0_re = x0_re + tr_re;
    assign y0_im = x0_im + tr_im;
    assign y1_re = x0_re - tr_re;
    assign y1_im = x0_im - tr_im;
endmodule