module butterfly_unit #(
    parameter integer DATA_W  = 16,
    parameter integer COEFF_W = 16
) (
    input  signed [DATA_W-1:0] xr,
    input  signed [DATA_W-1:0] xi,
    input  signed [DATA_W-1:0] yr,
    input  signed [DATA_W-1:0] yi,
    input  signed [COEFF_W-1:0] cos_q15,
    input  signed [COEFF_W-1:0] sin_q15,
    output signed [DATA_W-1:0] out1_r,
    output signed [DATA_W-1:0] out1_i,
    output signed [DATA_W-1:0] out2_r,
    output signed [DATA_W-1:0] out2_i
);
    // Number of fractional bits in Q1.15
    localparam integer FRAC   = COEFF_W - 1;
    // Full precision product width
    localparam integer PROD_W = DATA_W + COEFF_W;
    // Rounding constant = 2^(FRAC-1)
    localparam signed [PROD_W-1:0] ROUND = 1 <<< (FRAC-1);

    // Complex multiply: (yr + j*yi) * (cos_q15 + j*sin_q15)
    wire signed [PROD_W-1:0] mul_yr_cos = $signed(yr) * $signed(cos_q15);
    wire signed [PROD_W-1:0] mul_yi_sin = $signed(yi) * $signed(sin_q15);
    wire signed [PROD_W-1:0] mul_yr_sin = $signed(yr) * $signed(sin_q15);
    wire signed [PROD_W-1:0] mul_yi_cos = $signed(yi) * $signed(cos_q15);

    // Rotate: real = yr*cos - yi*sin, imag = yr*sin + yi*cos
    wire signed [PROD_W-1:0] rot_r = mul_yr_cos - mul_yi_sin;
    wire signed [PROD_W-1:0] rot_i = mul_yr_sin + mul_yi_cos;

    // Add rounding constant then shift back by FRAC bits
    wire signed [PROD_W-1:0] rot_r_rnd = rot_r + ROUND;
    wire signed [PROD_W-1:0] rot_i_rnd = rot_i + ROUND;
    wire signed [PROD_W-1:0] rot_r_sh  = rot_r_rnd >>> FRAC;
    wire signed [PROD_W-1:0] rot_i_sh  = rot_i_rnd >>> FRAC;

    // Truncate to DATA_W bits
    wire signed [DATA_W-1:0] tr = rot_r_sh[DATA_W-1:0];
    wire signed [DATA_W-1:0] ti = rot_i_sh[DATA_W-1:0];

    // Radix-2 butterfly outputs
    assign out1_r = xr + tr;
    assign out1_i = xi + ti;
    assign out2_r = xr - tr;
    assign out2_i = xi - ti;

endmodule