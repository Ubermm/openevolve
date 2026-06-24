`timescale 1ns/1ps

module sqrt_newton_raphson_fixedpoint #(
    parameter N = 16,
    parameter M = 8,
    parameter ITER_MAX = 10
)(
    input clk,
    input rst,
    input start,
    input [N-1:0] X,
    output reg [N-1:0] sqrt_result,
    output reg ready
);

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
            if (clog2 == 0)
                clog2 = 1;
        end
    endfunction

    localparam STATE_IDLE = 2'd0;
    localparam STATE_CALC = 2'd1;
    localparam STATE_DONE = 2'd2;

    localparam ITER_W = clog2(ITER_MAX + 1);
    localparam [ITER_W-1:0] ITER_LAST =
        (ITER_MAX > 0) ? (ITER_MAX - 1) : 0;

    reg [1:0] state;
    reg [N-1:0] X_reg;
    reg [N-1:0] y_reg;
    reg [ITER_W-1:0] iter_count;

    wire [N-1:0] initial_guess;
    wire input_is_zero;

    wire [N-1:0] div_term;
    wire [N-1:0] next_y;
    wire converged;

    wire last_iteration;

    assign last_iteration = (iter_count == ITER_LAST);

    sqrt_nr_initial_guess_fixedpoint #(
        .N(N),
        .M(M)
    ) u_initial_guess (
        .X(X),
        .initial_guess(initial_guess),
        .zero_flag(input_is_zero)
    );

    sqrt_nr_fixedpoint_divide #(
        .N(N),
        .M(M)
    ) u_divide (
        .X(X_reg),
        .y(y_reg),
        .quotient(div_term)
    );

    sqrt_nr_average_update #(
        .N(N)
    ) u_average_update (
        .current_y(y_reg),
        .div_term(div_term),
        .next_y(next_y)
    );

    sqrt_nr_convergence_check #(
        .N(N),
        .THRESHOLD(1)
    ) u_convergence_check (
        .current_y(y_reg),
        .next_y(next_y),
        .converged(converged)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            X_reg <= {N{1'b0}};
            y_reg <= {N{1'b0}};
            iter_count <= {ITER_W{1'b0}};
            sqrt_result <= {N{1'b0}};
            ready <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    ready <= 1'b0;
                    iter_count <= {ITER_W{1'b0}};

                    if (start) begin
                        X_reg <= X;
                        y_reg <= initial_guess;

                        if (input_is_zero) begin
                            sqrt_result <= {N{1'b0}};
                            ready <= 1'b1;
                            state <= STATE_DONE;
                        end else begin
                            state <= STATE_CALC;
                        end
                    end
                end

                STATE_CALC: begin
                    y_reg <= next_y;
                    iter_count <= iter_count + {{(ITER_W-1){1'b0}}, 1'b1};

                    if (converged || last_iteration) begin
                        sqrt_result <= next_y;
                        ready <= 1'b1;
                        state <= STATE_DONE;
                    end else begin
                        ready <= 1'b0;
                    end
                end

                STATE_DONE: begin
                    ready <= 1'b1;
                    state <= STATE_DONE;
                end

                default: begin
                    state <= STATE_IDLE;
                    ready <= 1'b0;
                    sqrt_result <= {N{1'b0}};
                    X_reg <= {N{1'b0}};
                    y_reg <= {N{1'b0}};
                    iter_count <= {ITER_W{1'b0}};
                end
            endcase
        end
    end

endmodule