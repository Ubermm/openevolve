module butterfly_unit #(
    parameter DATA_W  = 12,
    parameter GAIN_W  = 4,
    parameter COEFF_W = 16
) (
    input  wire signed [DATA_W+GAIN_W-1:0] p_re_in,
    input  wire signed [DATA_W+GAIN_W-1:0] p_im_in,
    input  wire signed [DATA_W+GAIN_W-1:0] q_re_in,
    input  wire signed [DATA_W+GAIN_W-1:0] q_im_in,
    input  wire signed [COEFF_W-1:0]       cos_q15,
    input  wire signed [COEFF_W-1:0]       sin_q15,
    output wire signed [DATA_W+GAIN_W-1:0] p_re_out,
    output wire signed [DATA_W+GAIN_W-1:0] p_im_out,
    output wire signed [DATA_W+GAIN_W-1:0] q_re_out,
    output wire signed [DATA_W+GAIN_W-1:0] q_im_out
);

    localparam integer P_W    = DATA_W + GAIN_W;
    localparam integer PROD_W = P_W + COEFF_W;
    localparam integer SHIFT  = COEFF_W - 1;
    localparam signed [PROD_W-1:0] ROUND_CONST = 1 <<< (SHIFT-1);

    // partial products
    wire signed [PROD_W-1:0] mult1 = q_re_in * cos_q15;
    wire signed [PROD_W-1:0] mult2 = q_im_in * sin_q15;
    wire signed [PROD_W-1:0] mult3 = q_re_in * sin_q15;
    wire signed [PROD_W-1:0] mult4 = q_im_in * cos_q15;

    // pre-rounding
    wire signed [PROD_W-1:0] tr_raw = mult1 - mult2;
    wire signed [PROD_W-1:0] ti_raw = mult3 + mult4;

    // rounding
    wire signed [PROD_W-1:0] tr_adj = (tr_raw >= 0) ? (tr_raw + ROUND_CONST) : (tr_raw - ROUND_CONST);
    wire signed [PROD_W-1:0] ti_adj = (ti_raw >= 0) ? (ti_raw + ROUND_CONST) : (ti_raw - ROUND_CONST);

    // shift
    wire signed [PROD_W-1:0] tr_sh = tr_adj >>> SHIFT;
    wire signed [PROD_W-1:0] ti_sh = ti_adj >>> SHIFT;

    // take P_W bits at [SHIFT+P_W-1:SHIFT]
    wire signed [P_W-1:0] tr = tr_sh[SHIFT+P_W-1:SHIFT];
    wire signed [P_W-1:0] ti = ti_sh[SHIFT+P_W-1:SHIFT];

    // butterfly
    wire signed [P_W:0] sum_re  = p_re_in + tr;
    wire signed [P_W:0] sum_im  = p_im_in + ti;
    wire signed [P_W:0] diff_re = p_re_in - tr;
    wire signed [P_W:0] diff_im = p_im_in - ti;

    assign p_re_out = sum_re[P_W-1:0];
    assign p_im_out = sum_im[P_W-1:0];
    assign q_re_out = diff_re[P_W-1:0];
    assign q_im_out = diff_im[P_W-1:0];

endmodule