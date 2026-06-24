`timescale 1ns/1ps

module gd_poly_step #(
    parameter integer N = 16,
    parameter integer M = 8
)(
    input  signed [N-1:0]     alpha,
    input  signed [(2*N):0]   gradient,
    output signed [(3*N):0]   step
);

    localparam integer GRAD_W = (2 * N) + 1;
    localparam integer STEP_W = (3 * N) + 1;

    wire signed [STEP_W-1:0] alpha_ext;
    wire signed [STEP_W-1:0] gradient_ext;
    wire signed [STEP_W-1:0] product;

    assign alpha_ext    = {{(STEP_W-N){alpha[N-1]}}, alpha};
    assign gradient_ext = {{(STEP_W-GRAD_W){gradient[GRAD_W-1]}}, gradient};

    assign product = alpha_ext * gradient_ext;

    generate
        if (M == 0) begin : gen_no_shift
            assign step = product;
        end else if (M >= STEP_W) begin : gen_full_shift
            assign step = {STEP_W{product[STEP_W-1]}};
        end else begin : gen_shift
            assign step = product >>> M;
        end
    endgenerate

endmodule