module gd_update_calc #(
    parameter N = 16,
    parameter M = 8,
    parameter G_WIDTH = (2*N) + 4
)(
    input  signed [N-1:0]       x,
    input  signed [N-1:0]       alpha,
    input  signed [G_WIDTH-1:0] gradient,
    output signed [N-1:0]       x_updated
);

    localparam PRODUCT_WIDTH = N + G_WIDTH;
    localparam UPDATE_WIDTH  = PRODUCT_WIDTH + 1;

    wire signed [PRODUCT_WIDTH-1:0] alpha_ext;
    wire signed [PRODUCT_WIDTH-1:0] gradient_ext;
    wire signed [PRODUCT_WIDTH-1:0] product_wide;
    wire signed [PRODUCT_WIDTH-1:0] scaled_step;

    wire signed [UPDATE_WIDTH-1:0] x_ext;
    wire signed [UPDATE_WIDTH-1:0] step_ext;
    wire signed [UPDATE_WIDTH-1:0] updated_wide;

    assign alpha_ext    = {{G_WIDTH{alpha[N-1]}}, alpha};
    assign gradient_ext = {{N{gradient[G_WIDTH-1]}}, gradient};

    assign product_wide = alpha_ext * gradient_ext;
    assign scaled_step  = product_wide >>> M;

    assign x_ext        = {{(UPDATE_WIDTH-N){x[N-1]}}, x};
    assign step_ext     = {{(UPDATE_WIDTH-PRODUCT_WIDTH){scaled_step[PRODUCT_WIDTH-1]}}, scaled_step};
    assign updated_wide = x_ext - step_ext;

    assign x_updated    = updated_wide[N-1:0];

endmodule