module butterfly_comb #(
  parameter integer DATA_W  = 16,
  parameter integer COEFF_W = 16
) (
  input  signed [DATA_W-1:0] x0_re,
  input  signed [DATA_W-1:0] x0_im,
  input  signed [DATA_W-1:0] x1_re,
  input  signed [DATA_W-1:0] x1_im,
  input  signed [COEFF_W-1:0] cos_w,
  input  signed [COEFF_W-1:0] sin_w,
  output signed [DATA_W:0]   y0_re,
  output signed [DATA_W:0]   y0_im,
  output signed [DATA_W:0]   y1_re,
  output signed [DATA_W:0]   y1_im
);

  // Rounding constant for Q1.(COEFF_W-1) multiply
  localparam integer RND = 1 << (COEFF_W-2);
  // width of full product
  localparam integer P_W = DATA_W + COEFF_W;

  // Complex multiply x1 * (cos_w + j*sin_w)
  wire signed [P_W-1:0] prod_re_re = x1_re * cos_w;  // x1_re * cos
  wire signed [P_W-1:0] prod_im_im = x1_im * sin_w;  // x1_im * sin
  wire signed [P_W-1:0] prod_re_im = x1_re * sin_w;  // x1_re * sin
  wire signed [P_W-1:0] prod_im_re = x1_im * cos_w;  // x1_im * cos

  // Combine real and imag parts
  wire signed [P_W-1:0] z_re = prod_re_re - prod_im_im;
  wire signed [P_W-1:0] z_im = prod_re_im + prod_im_re;

  // Symmetric rounding: add half LSB or subtract for negative
  wire signed [P_W-1:0] rnd_re = z_re[ P_W-1 ] ? -RND : RND;
  wire signed [P_W-1:0] rnd_im = z_im[ P_W-1 ] ? -RND : RND;
  wire signed [P_W-1:0] z_re_rnd = z_re + rnd_re;
  wire signed [P_W-1:0] z_im_rnd = z_im + rnd_im;

  // Shift right by (COEFF_W-1) to align back to DATA_W bits
  wire signed [DATA_W-1:0] t_re = z_re_rnd[ COEFF_W-1 + DATA_W-1 : COEFF_W-1 ];
  wire signed [DATA_W-1:0] t_im = z_im_rnd[ COEFF_W-1 + DATA_W-1 : COEFF_W-1 ];

  // Butterfly add/subtract, one extra bit growth
  wire signed [DATA_W:0] sum_re  = x0_re + t_re;
  wire signed [DATA_W:0] sum_im  = x0_im + t_im;
  wire signed [DATA_W:0] diff_re = x0_re - t_re;
  wire signed [DATA_W:0] diff_im = x0_im - t_im;

  // Outputs
  assign y0_re = sum_re;
  assign y0_im = sum_im;
  assign y1_re = diff_re;
  assign y1_im = diff_im;

endmodule