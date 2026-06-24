`timescale 1ns/1ps

module sqrt_nr_convergence_check #(
    parameter N = 16,
    parameter THRESHOLD = 1
)(
    input [N-1:0] current_y,
    input [N-1:0] next_y,
    output converged
);

    assign converged = 1'b0;

endmodule