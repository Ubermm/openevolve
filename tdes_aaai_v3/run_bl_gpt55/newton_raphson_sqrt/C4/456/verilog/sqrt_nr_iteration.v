`timescale 1ns/1ps

module sqrt_nr_iteration #(
    parameter N = 16,
    parameter M = 8
)(
    input  [N-1:0] X,
    input  [N-1:0] y_current,
    output reg [N-1:0] y_next
);

    localparam integer DIV_W = N + M;
    localparam integer SUM_W = DIV_W + 1;

    reg [DIV_W-1:0] scaled_X;
    reg [DIV_W-1:0] quotient;
    reg [SUM_W-1:0] sum_ext;
    reg [SUM_W-1:0] avg_ext;

    always @* begin
        scaled_X = X;
        scaled_X = scaled_X << M;

        quotient = {DIV_W{1'b0}};
        sum_ext  = {SUM_W{1'b0}};
        avg_ext  = {SUM_W{1'b0}};
        y_next   = {N{1'b0}};

        if (y_current == {N{1'b0}}) begin
            if (X == {N{1'b0}})
                y_next = {N{1'b0}};
            else
                y_next = {N{1'b1}};
        end else begin
            quotient = scaled_X / y_current;

            sum_ext = quotient;
            sum_ext = sum_ext + y_current;

            avg_ext = (sum_ext + {{DIV_W{1'b0}}, 1'b1}) >> 1;

            if (avg_ext[SUM_W-1:N] != {(SUM_W-N){1'b0}})
                y_next = {N{1'b1}};
            else
                y_next = avg_ext[N-1:0];
        end
    end

endmodule