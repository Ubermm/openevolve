`timescale 1ns/1ps

module sqrt_fixedpoint_convergence #(
    parameter N = 16,
    parameter THRESHOLD = 1
)(
    input [N-1:0] y_current,
    input [N-1:0] y_next,
    output reg converged
);

    always @* begin
        converged = 1'b0;
    end

endmodule