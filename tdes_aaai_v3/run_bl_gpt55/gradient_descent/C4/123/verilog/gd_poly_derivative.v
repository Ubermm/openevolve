`timescale 1ns/1ps

module gd_poly_derivative #(
    parameter N = 16,
    parameter M = 8
)(
    input  signed [N-1:0] x,
    input  signed [N-1:0] a,
    input  signed [N-1:0] b,
    output signed [(2*N):0] gradient
);

    localparam GRAD_W = (2 * N) + 1;

    wire signed [GRAD_W-1:0] a_ext;
    wire signed [GRAD_W-1:0] x_ext;
    wire signed [GRAD_W-1:0] b_ext;

    wire signed [GRAD_W-1:0] ax_product;
    wire signed [GRAD_W-1:0] two_ax_product;
    wire signed [GRAD_W-1:0] scaled_two_ax;

    assign a_ext = {{(GRAD_W-N){a[N-1]}}, a};
    assign x_ext = {{(GRAD_W-N){x[N-1]}}, x};
    assign b_ext = {{(GRAD_W-N){b[N-1]}}, b};

    assign ax_product     = a_ext * x_ext;
    assign two_ax_product = ax_product <<< 1;
    assign scaled_two_ax  = two_ax_product >>> M;

    assign gradient = scaled_two_ax + b_ext;

endmodule