`timescale 1ns/1ps

module sqrt_nr_initial_guess_fixedpoint #(
    parameter N = 16,
    parameter M = 8
)(
    input  [N-1:0] X,
    output [N-1:0] initial_guess,
    output zero_flag
);

    localparam [N-1:0] ONE_Q = (M < N) ? ({ {N-1{1'b0}}, 1'b1 } << M) : {N{1'b1}};

    assign zero_flag     = (X == {N{1'b0}});
    assign initial_guess = zero_flag ? ONE_Q : X;

endmodule