module gs_iteration_2x2 #(
    parameter DATA_WIDTH = 32,
    parameter FRAC = 16
)(
    input  [DATA_WIDTH-1:0] a12,
    input  [DATA_WIDTH-1:0] a21,
    input  [DATA_WIDTH-1:0] b1,
    input  [DATA_WIDTH-1:0] b2,
    input  [DATA_WIDTH-1:0] inv_a11,
    input  [DATA_WIDTH-1:0] inv_a22,
    input  [DATA_WIDTH-1:0] x2_current,
    output reg [DATA_WIDTH-1:0] x1_next,
    output reg [DATA_WIDTH-1:0] x2_next
);

    localparam PROD_WIDTH  = 2 * DATA_WIDTH;
    localparam RES_WIDTH   = (2 * DATA_WIDTH) + 1;
    localparam XPROD_WIDTH = (3 * DATA_WIDTH) + 1;

    wire signed [DATA_WIDTH-1:0] a12_s        = a12;
    wire signed [DATA_WIDTH-1:0] a21_s        = a21;
    wire signed [DATA_WIDTH-1:0] b1_s         = b1;
    wire signed [DATA_WIDTH-1:0] b2_s         = b2;
    wire signed [DATA_WIDTH-1:0] inv_a11_s    = inv_a11;
    wire signed [DATA_WIDTH-1:0] inv_a22_s    = inv_a22;
    wire signed [DATA_WIDTH-1:0] x2_current_s = x2_current;

    wire signed [PROD_WIDTH-1:0] a12_ext_prod =
        {{DATA_WIDTH{a12_s[DATA_WIDTH-1]}}, a12_s};
    wire signed [PROD_WIDTH-1:0] x2_ext_prod =
        {{DATA_WIDTH{x2_current_s[DATA_WIDTH-1]}}, x2_current_s};

    wire signed [PROD_WIDTH-1:0] a12_x2_prod =
        a12_ext_prod * x2_ext_prod;

    wire signed [RES_WIDTH-1:0] b1_ext_res =
        {{(RES_WIDTH-DATA_WIDTH){b1_s[DATA_WIDTH-1]}}, b1_s};
    wire signed [RES_WIDTH-1:0] a12_x2_ext_res =
        {a12_x2_prod[PROD_WIDTH-1], a12_x2_prod};

    wire signed [RES_WIDTH-1:0] residual1_q2f =
        (b1_ext_res <<< FRAC) - a12_x2_ext_res;

    wire signed [XPROD_WIDTH-1:0] residual1_ext_xprod =
        {{(XPROD_WIDTH-RES_WIDTH){residual1_q2f[RES_WIDTH-1]}}, residual1_q2f};
    wire signed [XPROD_WIDTH-1:0] inv_a11_ext_xprod =
        {{(XPROD_WIDTH-DATA_WIDTH){inv_a11_s[DATA_WIDTH-1]}}, inv_a11_s};

    wire signed [XPROD_WIDTH-1:0] x1_prod_q3f =
        residual1_ext_xprod * inv_a11_ext_xprod;

    wire signed [XPROD_WIDTH-1:0] x1_scaled_wide =
        x1_prod_q3f >>> (2 * FRAC);

    wire signed [DATA_WIDTH-1:0] x1_calc =
        x1_scaled_wide[DATA_WIDTH-1:0];

    wire signed [PROD_WIDTH-1:0] a21_ext_prod =
        {{DATA_WIDTH{a21_s[DATA_WIDTH-1]}}, a21_s};
    wire signed [PROD_WIDTH-1:0] x1_ext_prod =
        {{DATA_WIDTH{x1_calc[DATA_WIDTH-1]}}, x1_calc};

    wire signed [PROD_WIDTH-1:0] a21_x1_prod =
        a21_ext_prod * x1_ext_prod;

    wire signed [RES_WIDTH-1:0] b2_ext_res =
        {{(RES_WIDTH-DATA_WIDTH){b2_s[DATA_WIDTH-1]}}, b2_s};
    wire signed [RES_WIDTH-1:0] a21_x1_ext_res =
        {a21_x1_prod[PROD_WIDTH-1], a21_x1_prod};

    wire signed [RES_WIDTH-1:0] residual2_q2f =
        (b2_ext_res <<< FRAC) - a21_x1_ext_res;

    wire signed [XPROD_WIDTH-1:0] residual2_ext_xprod =
        {{(XPROD_WIDTH-RES_WIDTH){residual2_q2f[RES_WIDTH-1]}}, residual2_q2f};
    wire signed [XPROD_WIDTH-1:0] inv_a22_ext_xprod =
        {{(XPROD_WIDTH-DATA_WIDTH){inv_a22_s[DATA_WIDTH-1]}}, inv_a22_s};

    wire signed [XPROD_WIDTH-1:0] x2_prod_q3f =
        residual2_ext_xprod * inv_a22_ext_xprod;

    wire signed [XPROD_WIDTH-1:0] x2_scaled_wide =
        x2_prod_q3f >>> (2 * FRAC);

    wire signed [DATA_WIDTH-1:0] x2_calc =
        x2_scaled_wide[DATA_WIDTH-1:0];

    always @* begin
        x1_next = x1_calc;
        x2_next = x2_calc;
    end

endmodule