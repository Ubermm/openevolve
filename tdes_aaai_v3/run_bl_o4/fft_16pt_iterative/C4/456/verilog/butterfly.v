module butterfly #(
  parameter BITW = 16,
  parameter C_W  = 16
)(
  input  signed [BITW-1:0] p_re,
  input  signed [BITW-1:0] p_im,
  input  signed [BITW-1:0] q_re,
  input  signed [BITW-1:0] q_im,
  input  signed [C_W-1:0]  tw_re,
  input  signed [C_W-1:0]  tw_im,
  output signed [BITW-1:0] out_p_re,
  output signed [BITW-1:0] out_p_im,
  output signed [BITW-1:0] out_q_re,
  output signed [BITW-1:0] out_q_im
);
  // Fixed-point shift and rounding constant for Q1.(C_W-1)
  localparam integer SHIFT = C_W - 1;
  localparam integer RND   = 1 << (SHIFT - 1);

  // Full-width products
  wire signed [BITW+C_W-1:0] prod_rr = q_re * tw_re; // q_re * tw_re
  wire signed [BITW+C_W-1:0] prod_ii = q_im * tw_im; // q_im * tw_im
  wire signed [BITW+C_W-1:0] prod_ri = q_re * tw_im; // q_re * tw_im
  wire signed [BITW+C_W-1:0] prod_ir = q_im * tw_re; // q_im * tw_re

  // Complex multiply (with rounding): tr + j*ti = (q_re + j*q_im)*(tw_re + j*tw_im)
  wire signed [BITW-1:0] tr = (prod_rr - prod_ii + RND) >>> SHIFT;
  wire signed [BITW-1:0] ti = (prod_ir + prod_ri + RND) >>> SHIFT;

  // Radix-2 DIT butterfly: sum and difference
  assign out_p_re = p_re + tr;
  assign out_p_im = p_im + ti;
  assign out_q_re = p_re - tr;
  assign out_q_im = p_im - ti;
endmodule