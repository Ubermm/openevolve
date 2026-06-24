`timescale 1ns/1ps

module gd_poly_update #(
    parameter integer N      = 16,
    parameter integer M      = 8,
    parameter integer STEP_W = (3*N + 1)
)(
    input  signed [N-1:0]      current_x,
    input  signed [STEP_W-1:0] step,
    output signed [N-1:0]      next_x
);

    localparam integer CALC_W = (STEP_W > N) ? (STEP_W + 1) : (N + 1);

    wire signed [CALC_W-1:0] current_x_ext;
    wire signed [CALC_W-1:0] step_ext;
    wire signed [CALC_W-1:0] diff_ext;

    assign current_x_ext = {{(CALC_W-N){current_x[N-1]}}, current_x};
    assign step_ext      = {{(CALC_W-STEP_W){step[STEP_W-1]}}, step};

    assign diff_ext = current_x_ext - step_ext;

    assign next_x = diff_ext[N-1:0];

endmodule