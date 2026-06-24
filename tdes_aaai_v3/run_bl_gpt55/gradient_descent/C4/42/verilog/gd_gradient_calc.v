module gd_gradient_calc #(
    parameter N = 16,
    parameter M = 8,
    parameter G_WIDTH = (2*N) + 4
)(
    input  signed [N-1:0] x,
    input  signed [N-1:0] a,
    input  signed [N-1:0] b,
    output signed [G_WIDTH-1:0] gradient
);

    localparam MIN_CALC_WIDTH = (2 * N) + 2;
    localparam CALC_WIDTH     = (G_WIDTH > MIN_CALC_WIDTH) ? G_WIDTH : MIN_CALC_WIDTH;

    wire signed [CALC_WIDTH-1:0] a_ext;
    wire signed [CALC_WIDTH-1:0] x_ext;
    wire signed [CALC_WIDTH-1:0] b_ext;

    wire signed [CALC_WIDTH-1:0] ax_product;
    wire signed [CALC_WIDTH-1:0] two_ax;
    wire signed [CALC_WIDTH-1:0] scaled_two_ax;
    wire signed [CALC_WIDTH-1:0] gradient_ext;

    assign a_ext = {{(CALC_WIDTH-N){a[N-1]}}, a};
    assign x_ext = {{(CALC_WIDTH-N){x[N-1]}}, x};
    assign b_ext = {{(CALC_WIDTH-N){b[N-1]}}, b};

    assign ax_product    = a_ext * x_ext;
    assign two_ax        = ax_product <<< 1;
    assign scaled_two_ax = two_ax >>> M;
    assign gradient_ext  = scaled_two_ax + b_ext;

    assign gradient = gradient_ext[G_WIDTH-1:0];

endmodule