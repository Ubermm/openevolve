module gd_derivative #(
    parameter N      = 16,
    parameter M      = 8,
    parameter GUARD  = 8,
    parameter XW     = 28,
    parameter GRAD_W = XW + N + 2
)(
    input  signed [XW-1:0]     x_val,
    input  signed [N-1:0]      a,
    input  signed [N-1:0]      b,
    output signed [GRAD_W-1:0] grad
);

    localparam PROD_W      = XW + N;
    localparam FULL_PROD_W = 2 * PROD_W;

    wire signed [PROD_W-1:0]      a_ext;
    wire signed [PROD_W-1:0]      x_ext;
    wire signed [FULL_PROD_W-1:0] ax_product_full;
    wire signed [PROD_W-1:0]      ax_product;

    wire signed [GRAD_W-1:0] ax_extended;
    wire signed [GRAD_W-1:0] two_ax_scaled;
    wire signed [GRAD_W-1:0] b_extended;
    wire signed [GRAD_W-1:0] b_scaled;

    assign a_ext = {{XW{a[N-1]}}, a};
    assign x_ext = {{N{x_val[XW-1]}}, x_val};

    assign ax_product_full = a_ext * x_ext;
    assign ax_product      = ax_product_full[PROD_W-1:0];

    assign ax_extended = {{(GRAD_W-PROD_W){ax_product[PROD_W-1]}}, ax_product};

    assign two_ax_scaled = (ax_extended <<< 1) >>> M;

    assign b_extended = {{(GRAD_W-N){b[N-1]}}, b};
    assign b_scaled   = b_extended <<< GUARD;

    assign grad = two_ax_scaled + b_scaled;

endmodule