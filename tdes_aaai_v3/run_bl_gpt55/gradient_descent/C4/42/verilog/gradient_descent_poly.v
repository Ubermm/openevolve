`timescale 1ns/1ps

module gradient_descent_poly #(
    parameter N = 16,
    parameter M = 8,
    parameter MAX_ITER = 10
)(
    input clk,
    input rst,
    input start,
    input signed [N-1:0] x,
    input signed [N-1:0] alpha,
    input signed [N-1:0] a,
    input signed [N-1:0] b,
    output reg signed [N-1:0] x_next,
    output reg ready
);

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam STATE_IDLE = 2'd0;
    localparam STATE_CALC = 2'd1;
    localparam STATE_DONE = 2'd2;

    localparam G_WIDTH = (2*N) + 4;
    localparam COUNT_W = (MAX_ITER <= 1) ? 1 : clog2(MAX_ITER);

    reg [1:0] state;
    reg signed [N-1:0] x_reg;
    reg [COUNT_W-1:0] iter_count;

    wire signed [G_WIDTH-1:0] gradient_w;
    wire signed [N-1:0] x_updated_w;
    wire last_iteration_w;

    gd_gradient_calc #(
        .N(N),
        .M(M),
        .G_WIDTH(G_WIDTH)
    ) u_gradient_calc (
        .x(x_reg),
        .a(a),
        .b(b),
        .gradient(gradient_w)
    );

    gd_update_calc #(
        .N(N),
        .M(M),
        .G_WIDTH(G_WIDTH)
    ) u_update_calc (
        .x(x_reg),
        .alpha(alpha),
        .gradient(gradient_w),
        .x_updated(x_updated_w)
    );

    gd_iteration_done #(
        .MAX_ITER(MAX_ITER),
        .CNT_WIDTH(COUNT_W)
    ) u_iteration_done (
        .iter_count(iter_count),
        .last_iteration(last_iteration_w)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= STATE_IDLE;
            x_reg      <= {N{1'b0}};
            iter_count <= {COUNT_W{1'b0}};
            x_next     <= {N{1'b0}};
            ready      <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    ready <= 1'b0;
                    iter_count <= {COUNT_W{1'b0}};

                    if (start) begin
                        x_reg <= x;

                        if (MAX_ITER == 0) begin
                            x_next <= x;
                            ready  <= 1'b1;
                            state  <= STATE_DONE;
                        end else begin
                            state <= STATE_CALC;
                        end
                    end
                end

                STATE_CALC: begin
                    x_reg <= x_updated_w;

                    if (last_iteration_w) begin
                        x_next <= x_updated_w;
                        ready  <= 1'b1;
                        state  <= STATE_DONE;
                    end else begin
                        iter_count <= iter_count + {{(COUNT_W-1){1'b0}}, 1'b1};
                    end
                end

                STATE_DONE: begin
                    ready  <= 1'b1;
                    x_next <= x_next;
                    x_reg  <= x_reg;
                    state  <= STATE_DONE;
                end

                default: begin
                    state      <= STATE_IDLE;
                    x_reg      <= {N{1'b0}};
                    iter_count <= {COUNT_W{1'b0}};
                    x_next     <= {N{1'b0}};
                    ready      <= 1'b0;
                end
            endcase
        end
    end

endmodule