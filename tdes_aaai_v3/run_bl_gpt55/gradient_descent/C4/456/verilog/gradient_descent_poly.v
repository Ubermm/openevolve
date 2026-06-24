`timescale 1ns/1ps

module gradient_descent_poly #(
    parameter N = 16,
    parameter M = 8,
    parameter MAX_ITER = 10,
    parameter GUARD = 8
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

    localparam STATE_IDLE = 2'd0;
    localparam STATE_CALC = 2'd1;
    localparam STATE_DONE = 2'd2;

    /*
      Internal x is kept with GUARD additional fractional bits and a few
      additional integer bits.  This reduces accumulated fixed-point
      quantization error while preserving the external Q(N,M) interface.
    */
    localparam XW      = N + GUARD + 4;
    localparam GRAD_W  = XW + N + 2;
    localparam STEP_W  = GRAD_W + N;

    reg [1:0] state;
    reg [31:0] iter_count;

    reg signed [XW-1:0] x_reg;
    reg signed [N-1:0] alpha_reg;
    reg signed [N-1:0] a_reg;
    reg signed [N-1:0] b_reg;

    wire signed [XW-1:0] x_initial_ext;
    wire signed [GRAD_W-1:0] gradient;
    wire signed [STEP_W-1:0] step;
    wire signed [XW-1:0] iter_x_next;
    wire signed [N-1:0] iter_x_next_q;

    assign x_initial_ext = $signed({{(XW-N){x[N-1]}}, x}) <<< GUARD;

    gd_derivative #(
        .N(N),
        .M(M),
        .GUARD(GUARD),
        .XW(XW),
        .GRAD_W(GRAD_W)
    ) u_derivative (
        .x_val(x_reg),
        .a(a_reg),
        .b(b_reg),
        .grad(gradient)
    );

    gd_step #(
        .N(N),
        .M(M),
        .GRAD_W(GRAD_W),
        .STEP_W(STEP_W)
    ) u_step (
        .alpha(alpha_reg),
        .grad(gradient),
        .step(step)
    );

    gd_update #(
        .XW(XW),
        .STEP_W(STEP_W)
    ) u_update (
        .x_val(x_reg),
        .step(step),
        .x_next_int(iter_x_next)
    );

    gd_output_quantizer #(
        .N(N),
        .XW(XW),
        .GUARD(GUARD)
    ) u_output_quantizer (
        .x_int(iter_x_next),
        .x_out(iter_x_next_q)
    );

    always @(posedge clk) begin
        if (rst) begin
            state      <= STATE_IDLE;
            iter_count <= 32'd0;
            x_reg      <= {XW{1'b0}};
            alpha_reg  <= {N{1'b0}};
            a_reg      <= {N{1'b0}};
            b_reg      <= {N{1'b0}};
            x_next     <= {N{1'b0}};
            ready      <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    ready <= 1'b0;
                    if (start) begin
                        alpha_reg  <= alpha;
                        a_reg      <= a;
                        b_reg      <= b;
                        x_reg      <= x_initial_ext;
                        iter_count <= 32'd0;

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
                    x_reg <= iter_x_next;

                    if (iter_count == (MAX_ITER - 1)) begin
                        x_next <= iter_x_next_q;
                        ready  <= 1'b1;
                        state  <= STATE_DONE;
                    end else begin
                        iter_count <= iter_count + 32'd1;
                    end
                end

                STATE_DONE: begin
                    /*
                      Per specification, remain in DONE with result latched
                      and ready asserted until an external reset is applied.
                    */
                    ready <= 1'b1;
                    state <= STATE_DONE;
                end

                default: begin
                    state      <= STATE_IDLE;
                    iter_count <= 32'd0;
                    ready      <= 1'b0;
                end
            endcase
        end
    end

endmodule