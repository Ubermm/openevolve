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
        integer temp;
        begin
            temp = value - 1;
            for (clog2 = 0; temp > 0; clog2 = clog2 + 1)
                temp = temp >> 1;
            if (clog2 < 1)
                clog2 = 1;
        end
    endfunction

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_CALC = 2'd1;
    localparam [1:0] ST_DONE = 2'd2;

    localparam integer ITER_W = clog2(ITER_MAX + 1);
    localparam integer ITER_LAST = (ITER_MAX > 0) ? (ITER_MAX - 1) : 0;

    reg [1:0] state;
    reg [N-1:0] X_reg;
    reg [N-1:0] y_reg;
    reg [ITER_W-1:0] iter_count;

    wire [N-1:0] initial_y;
    wire input_is_zero;

    wire [N-1:0] y_next;
    wire converged;

    sqrt_fixedpoint_initial_guess #(
        .N(N),
        .M(M)
    ) u_initial_guess (
        .X(X),
        .initial_y(initial_y),
        .is_zero(input_is_zero)
    );

    sqrt_fixedpoint_nr_step #(
        .N(N),
        .M(M)
    ) u_nr_step (
        .X(X_reg),
        .y_current(y_reg),
        .y_next(y_next)
    );

    sqrt_fixedpoint_convergence #(
        .N(N),
        .THRESHOLD(1)
    ) u_convergence (
        .y_current(y_reg),
        .y_next(y_next),
        .converged(converged)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= ST_IDLE;
            X_reg       <= {N{1'b0}};
            y_reg       <= {N{1'b0}};
            iter_count  <= {ITER_W{1'b0}};
            sqrt_result <= {N{1'b0}};
            ready       <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    ready <= 1'b0;

                    if (start) begin
                        X_reg      <= X;
                        iter_count <= {ITER_W{1'b0}};

                        if (input_is_zero) begin
                            y_reg       <= {N{1'b0}};
                            sqrt_result <= {N{1'b0}};
                            ready       <= 1'b1;
                            state       <= ST_DONE;
                        end else begin
                            y_reg       <= initial_y;
                            sqrt_result <= {N{1'b0}};
                            state       <= ST_CALC;
                        end
                    end
                end

                ST_CALC: begin
                    if (converged || (iter_count >= ITER_LAST[ITER_W-1:0])) begin
                        y_reg       <= y_next;
                        sqrt_result <= y_next;
                        ready       <= 1'b1;
                        state       <= ST_DONE;
                    end else begin
                        y_reg      <= y_next;
                        iter_count <= iter_count + {{(ITER_W-1){1'b0}}, 1'b1};
                        ready      <= 1'b0;
                    end
                end

                ST_DONE: begin
                    ready <= 1'b1;
                    state <= ST_DONE;
                end

                default: begin
                    state       <= ST_IDLE;
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