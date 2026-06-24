`timescale 1ns/1ps

module sqrt_fixedpoint_initial_guess #(
    parameter N = 16,
    parameter M = 8
)(
    input  [N-1:0] X,
    output reg [N-1:0] initial_y,
    output reg is_zero
);

    reg [N+M-1:0] scaled_x;
    integer i;
    integer msb_index;
    integer guess_index;

    always @* begin
        scaled_x   = {{M{1'b0}}, X} << M;
        initial_y  = {N{1'b0}};
        is_zero    = (X == {N{1'b0}});
        msb_index  = 0;
        guess_index = 0;

        if (!is_zero) begin
            for (i = 0; i < N+M; i = i + 1) begin
                if (scaled_x[i]) begin
                    msb_index = i;
                end
            end

            guess_index = (msb_index + 1) >> 1;

            if (guess_index >= N) begin
                initial_y[N-1] = 1'b1;
            end else begin
                initial_y[guess_index] = 1'b1;
            end
        end
    end

endmodule