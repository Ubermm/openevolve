`timescale 1ns/1ps

module sqrt_nr_convergence #(
    parameter N = 16,
    parameter TOLERANCE = 1
)(
    input  [N-1:0] y_current,
    input  [N-1:0] y_next,
    output converged
);

    assign converged = 1'b0;

endmodule