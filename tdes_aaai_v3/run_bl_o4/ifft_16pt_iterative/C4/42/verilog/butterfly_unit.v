module butterfly_unit #(
  parameter integer DATA_W  = 12,
  parameter integer GAIN_W  = 4,
  parameter integer COEFF_W = 16
) (
  input  wire signed [DATA_W+GAIN_W-1:0] a_re,
  input  wire signed [DATA_W+GAIN_W-1:0] a_im,
  input  wire signed [DATA_W+GAIN_W-1:0] b_re,
  input  wire signed [DATA_W+GAIN_W-1:0] b_im,
  input  wire signed [COEFF_W-1:0]       cos_q15,
  input  wire signed [COEFF_W-1:0]       sin_q15,
  output wire signed [DATA_W+GAIN_W-1:0] y0_re,
  output wire signed [DATA_W+GAIN_W-1:0] y0_im,
  output wire signed [DATA_W+GAIN_W-1:0] y1_re,
  output wire signed [DATA_W+GAIN_W-1:0] y1_im
);

  // Full-product width
  localparam integer PROD_W = (DATA_W + GAIN_W) + COEFF_W;
  // Number of fractional bits in twiddle (Q1.15)
  localparam integer SHIFT = COEFF_W - 1;
  // Rounding constant = 2^(SHIFT-1)
  localparam signed [PROD_W-1:0] RND =
    $signed({{(PROD_W-1){1'b0}}, 1'b1} << (SHIFT-1));

  // Raw products
  wire signed [PROD_W-1:0] mul_br_cr = b_re * cos_q15;
  wire signed [PROD_W-1:0] mul_bi_si = b_im * sin_q15;
  wire signed [PROD_W-1:0] mul_br_sr = b_re * sin_q15;
  wire signed [PROD_W-1:0] mul_bi_cr = b_im * cos_q15;

  // Complex rotate (conjugated sine for IFFT)
  wire signed [PROD_W-1:0] rot_re = mul_br_cr - mul_bi_si;
  wire signed [PROD_W-1:0] rot_im = mul_br_sr + mul_bi_cr;

  // Round and shift back to Q1.15
  wire signed [PROD_W-1:0] rot_re_rnd = rot_re + RND;
  wire signed [PROD_W-1:0] rot_im_rnd = rot_im + RND;
  wire signed [PROD_W-1:0] rot_re_sh  = rot_re_rnd  >>> SHIFT;
  wire signed [PROD_W-1:0] rot_im_sh  = rot_im_rnd  >>> SHIFT;

  // Truncate to DATA_W+GAIN_W bits
  wire signed [DATA_W+GAIN_W-1:0] t_re = rot_re_sh[DATA_W+GAIN_W-1:0];
  wire signed [DATA_W+GAIN_W-1:0] t_im = rot_im_sh[DATA_W+GAIN_W-1:0];

  // Butterfly: sum and difference
  assign y0_re = a_re + t_re;
  assign y0_im = a_im + t_im;
  assign y1_re = a_re - t_re;
  assign y1_im = a_im - t_im;

endmodule