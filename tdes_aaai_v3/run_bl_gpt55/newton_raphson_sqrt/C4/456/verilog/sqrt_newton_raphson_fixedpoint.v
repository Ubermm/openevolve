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
        begin
            value = value - 1;
            for (clog2 = 0; value > 0; clog2 = clog2 + 1)
                value = value >> 1;
        end
    endfunction

    localparam STATE_IDLE = 2'd0;
    localparam STATE_CALC = 2'd1;
    localparam STATE_DONE = 2'd2;

    localparam ITER_W = clog2(ITER_MAX + 1);

    reg [1:0] state;
    reg [N-1:0] X_reg;
    reg [N-1:0] y_reg;
    reg [ITER_W-1:0] iter_count;

    wire [N-1:0] initial_y;
    wire input_is_zero;

    wire [N-1:0] y_next;
    wire converged;

    sqrt_nr_initial_guess #(
        .N(N),
        .M(M)
    ) u_initial_guess (
        .X(X),
        .y0(initial_y),
        .is_zero(input_is_zero)
    );

    sqrt_nr_iteration #(
        .N(N),
        .M(M)
    ) u_iteration (
        .X(X_reg),
        .y_current(y_reg),
        .y_next(y_next)
    );

    sqrt_nr_convergence #(
        .N(N),
        .TOLERANCE(1)
    ) u_convergence (
        .y_current(y_reg),
        .y_next(y_next),
        .converged(converged)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= STATE_IDLE;
            X_reg       <= {N{1'b0}};
            y_reg       <= {N{1'b0}};
            iter_count  <= {ITER_W{1'b0}};
            sqrt_result <= {N{1'b0}};
            ready       <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    ready <= 1'b0;

                    if (start) begin
                        X_reg      <= X;
                        y_reg      <= initial_y;
                        iter_count <= {ITER_W{1'b0}};

                        if (input_is_zero) begin
                            sqrt_result <= {N{1'b0}};
                            ready       <= 1'b1;
                            state       <= STATE_DONE;
                        end else begin
                            state <= STATE_CALC;
                        end
                    end
                end

                STATE_CALC: begin
                    y_reg <= y_next;

                    if (converged || (iter_count == (ITER_MAX - 1))) begin
                        sqrt_result <= y_next;
                        ready       <= 1'b1;
                        state       <= STATE_DONE;
                    end else begin
                        iter_count <= iter_count + {{(ITER_W-1){1'b0}}, 1'b1};
                    end
                end

                STATE_DONE: begin
                    ready <= 1'b1;
                    state <= STATE_DONE;
                end

                default: begin
                    state       <= STATE_IDLE;
                    X_reg       <= {N{1'b0}};
                    y_reg       <= {N{1'b0}};
                    iter_count  <= {ITER_W{1'b0}};
                    sqrt_result <= {N{1'b0}};
                    ready       <= 1'b0;
                end
            endcase
        end
    end

endmodule