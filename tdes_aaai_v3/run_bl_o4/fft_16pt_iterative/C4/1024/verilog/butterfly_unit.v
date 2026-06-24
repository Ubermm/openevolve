module butterfly_unit #(
    parameter integer DATA_WG  = 16,
    parameter integer COEFF_W  = 16
) (
    input  wire signed [DATA_WG-1:0]    ar,
    input  wire signed [DATA_WG-1:0]    ai,
    input  wire signed [DATA_WG-1:0]    br,
    input  wire signed [DATA_WG-1:0]    bi,
    input  wire signed [COEFF_W-1:0]    cos_q15,
    input  wire signed [COEFF_W-1:0]    sin_q15,
    input  wire                          mode,     // 0: FFT, 1: IFFT
    output wire signed [DATA_WG:0]      xr,
    output wire signed [DATA_WG:0]      xi,
    output wire signed [DATA_WG:0]      yr,
    output wire signed [DATA_WG:0]      yi
);

    // shift for Q1.15 multiply
    localparam integer SHIFT = COEFF_W - 1;
    // width of multiply accumulators
    localparam integer INT_W = DATA_WG + COEFF_W;
    // rounding constant = 2^(SHIFT-1) per spec (+2^14 for COEFF_W=16)
    localparam signed [INT_W-1:0] RND = 1 <<< (SHIFT-1);

    // for IFFT, conjugate twiddle = cos + j*sin; for FFT, cos - j*sin
    wire signed [COEFF_W-1:0] sin_r = mode ? -sin_q15 : sin_q15;
    wire signed [COEFF_W-1:0] sin_i = -sin_r;

    // compute rotated "tr" = br*cos + bi*sin_r  (with rounding)
    wire signed [INT_W-1:0] m0 = br  * cos_q15;
    wire signed [INT_W-1:0] m1 = bi  * sin_r;
    wire signed [INT_W-1:0] sum0 = m0 + m1 + RND;
    wire signed [DATA_WG:0] tr   = sum0 >>> SHIFT;

    // compute rotated "ti" = bi*cos + br*sin_i
    wire signed [INT_W-1:0] m2 = bi  * cos_q15;
    wire signed [INT_W-1:0] m3 = br  * sin_i;
    wire signed [INT_W-1:0] sum1 = m2 + m3 + RND;
    wire signed [DATA_WG:0] ti   = sum1 >>> SHIFT;

    // butterfly outputs: sum and difference
    assign xr = ar + tr;
    assign xi = ai + ti;
    assign yr = ar - tr;
    assign yi = ai - ti;

endmodule