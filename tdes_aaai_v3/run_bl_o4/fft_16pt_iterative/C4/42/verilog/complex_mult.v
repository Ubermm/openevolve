module complex_mult #(
    parameter DATA_W  = 12,    // Width of input data (real and imag)
    parameter GAIN_W  = 4,     // Bit growth from FFT stages
    parameter COEFF_W = 16     // Width of twiddle coefficients (Q1.15)
) (
    input  wire                        clk,      // optional pipeline clock
    input  wire                        rst,      // optional pipeline reset
    input  wire signed [DATA_W+GAIN_W-1:0] a_re,  // input real
    input  wire signed [DATA_W+GAIN_W-1:0] a_im,  // input imag
    input  wire signed [COEFF_W-1:0]       b_re,  // twiddle real (Q1.15)
    input  wire signed [COEFF_W-1:0]       b_im,  // twiddle imag (Q1.15)
    output wire signed [DATA_W+GAIN_W-1:0] p_re,  // product real
    output wire signed [DATA_W+GAIN_W-1:0] p_im   // product imag
);

    // Output width after growth
    localparam OUT_W  = DATA_W + GAIN_W;
    // Width of full precision multiplies
    localparam PROD_W = OUT_W + COEFF_W;
    // Width to hold sum/diff with sign
    localparam SUM_W  = PROD_W + 1;
    // Rounding constant: 1 << (COEFF_W-1), extended to SUM_W bits
    localparam signed [SUM_W-1:0] ROUND = 
        {{(SUM_W-COEFF_W-1){1'b0}}, 1'b1, {(COEFF_W-1){1'b0}}};

    // partial products
    wire signed [PROD_W-1:0] mult_re1 = a_re * b_re; // a_re * b_re
    wire signed [PROD_W-1:0] mult_re2 = a_im * b_im; // a_im * b_im
    wire signed [PROD_W-1:0] mult_im1 = a_im * b_re; // a_im * b_re
    wire signed [PROD_W-1:0] mult_im2 = a_re * b_im; // a_re * b_im

    // sum/difference for complex multiply:
    // real = a_re*b_re + a_im*b_im
    // imag = a_im*b_re - a_re*b_im
    wire signed [SUM_W-1:0] sum_re = 
          {{mult_re1[PROD_W-1]}, mult_re1}
        + {{mult_re2[PROD_W-1]}, mult_re2};

    wire signed [SUM_W-1:0] sum_im = 
          {{mult_im1[PROD_W-1]}, mult_im1}
        - {{mult_im2[PROD_W-1]}, mult_im2};

    // add rounding bias
    wire signed [SUM_W-1:0] sum_re_rnd = sum_re + ROUND;
    wire signed [SUM_W-1:0] sum_im_rnd = sum_im + ROUND;

    // truncate: keep bits [COEFF_W+OUT_W-2 : COEFF_W-1]
    // (ROUND brings fractional bit above COEFF_W-1 into integer region)
    assign p_re = sum_re_rnd[COEFF_W + OUT_W - 2 : COEFF_W - 1];
    assign p_im = sum_im_rnd[COEFF_W + OUT_W - 2 : COEFF_W - 1];

endmodule