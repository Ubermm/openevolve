`timescale 1ns/1ps

module sqrt_nr_initial_guess #(
    parameter N = 16,
    parameter M = 8
)(
    input  [N-1:0] X,
    output [N-1:0] y0,
    output is_zero
);

    localparam [N-1:0] ONE_FIXED = ({{(N-1){1'b0}}, 1'b1} << M);

    assign is_zero = (X == {N{1'b0}});

    assign y0 = is_zero ? {N{1'b0}} :
                (X < ONE_FIXED) ? ONE_FIXED :
                X;

endmodule