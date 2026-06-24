`timescale 1ns/1ps

module sqrt_fixedpoint_nr_step #(
    parameter N = 16,
    parameter M = 8
)(
    input  [N-1:0] X,
    input  [N-1:0] y_current,
    output reg [N-1:0] y_next
);

    localparam W = N + M;

    reg [W-1:0] scaled_X;
    reg [W-1:0] quotient;
    reg [W:0]   sum;

    always @* begin
        scaled_X = X;
        scaled_X = scaled_X << M;

        quotient = {W{1'b0}};
        sum      = {(W+1){1'b0}};
        y_next   = {N{1'b0}};

        if (y_current != {N{1'b0}}) begin
            quotient = scaled_X / y_current;
            sum      = {{(M+1){1'b0}}, y_current} + {1'b0, quotient};
            y_next   = sum[N:1];
        end
    end

endmodule