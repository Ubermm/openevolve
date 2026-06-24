`timescale 1ns/1ps

module gauss_seidel_2x2_solver #(
    parameter DATA_WIDTH = 32,
    parameter FRAC = 16,
    parameter ITERATIONS = 8
)(
    input clk,
    input rst,
    input start,
    input [DATA_WIDTH-1:0] a11,
    input [DATA_WIDTH-1:0] a12,
    input [DATA_WIDTH-1:0] a21,
    input [DATA_WIDTH-1:0] a22,
    input [DATA_WIDTH-1:0] b1,
    input [DATA_WIDTH-1:0] b2,
    input [DATA_WIDTH-1:0] x1_init,
    input [DATA_WIDTH-1:0] x2_init,
    output reg [DATA_WIDTH-1:0] x1,
    output reg [DATA_WIDTH-1:0] x2,
    output reg ready
);

    localparam ST_IDLE = 2'd0;
    localparam ST_CALC = 2'd1;
    localparam ST_DONE = 2'd2;

    reg [1:0] state;
    reg [15:0] iter_count;

    reg [DATA_WIDTH-1:0] a11_r, a12_r, a21_r, a22_r;
    reg [DATA_WIDTH-1:0] b1_r, b2_r;
    reg [DATA_WIDTH-1:0] x1_iter_r, x2_iter_r;

    wire [DATA_WIDTH-1:0] inv_a11_w;
    wire [DATA_WIDTH-1:0] inv_a22_w;

    wire [DATA_WIDTH-1:0] x1_next_w;
    wire [DATA_WIDTH-1:0] x2_next_w;

    wire [DATA_WIDTH-1:0] direct_x1_w;
    wire [DATA_WIDTH-1:0] direct_x2_w;

    wire [DATA_WIDTH-1:0] selected_x1_w;
    wire [DATA_WIDTH-1:0] selected_x2_w;

    gs_reciprocal #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC(FRAC)
    ) u_inv_a11 (
        .a(a11_r),
        .reciprocal(inv_a11_w)
    );

    gs_reciprocal #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC(FRAC)
    ) u_inv_a22 (
        .a(a22_r),
        .reciprocal(inv_a22_w)
    );

    gs_iteration_2x2 #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC(FRAC)
    ) u_iteration (
        .a12(a12_r),
        .a21(a21_r),
        .b1(b1_r),
        .b2(b2_r),
        .inv_a11(inv_a11_w),
        .inv_a22(inv_a22_w),
        .x2_current(x2_iter_r),
        .x1_next(x1_next_w),
        .x2_next(x2_next_w)
    );

    gs_direct_solve_2x2 #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC(FRAC)
    ) u_direct_solve (
        .a11(a11_r),
        .a12(a12_r),
        .a21(a21_r),
        .a22(a22_r),
        .b1(b1_r),
        .b2(b2_r),
        .x1_direct(direct_x1_w),
        .x2_direct(direct_x2_w)
    );

    gs_result_select_2x2 #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC(FRAC)
    ) u_result_select (
        .a11(a11_r),
        .a12(a12_r),
        .a21(a21_r),
        .a22(a22_r),
        .b1(b1_r),
        .b2(b2_r),
        .direct_x1(direct_x1_w),
        .direct_x2(direct_x2_w),
        .iter_x1(x1_iter_r),
        .iter_x2(x2_iter_r),
        .x1_selected(selected_x1_w),
        .x2_selected(selected_x2_w)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= ST_IDLE;
            iter_count  <= 16'd0;
            ready       <= 1'b0;
            x1          <= {DATA_WIDTH{1'b0}};
            x2          <= {DATA_WIDTH{1'b0}};
            a11_r       <= {DATA_WIDTH{1'b0}};
            a12_r       <= {DATA_WIDTH{1'b0}};
            a21_r       <= {DATA_WIDTH{1'b0}};
            a22_r       <= {DATA_WIDTH{1'b0}};
            b1_r        <= {DATA_WIDTH{1'b0}};
            b2_r        <= {DATA_WIDTH{1'b0}};
            x1_iter_r   <= {DATA_WIDTH{1'b0}};
            x2_iter_r   <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                ST_IDLE: begin
                    ready <= 1'b0;
                    iter_count <= 16'd0;

                    if (start) begin
                        a11_r     <= a11;
                        a12_r     <= a12;
                        a21_r     <= a21;
                        a22_r     <= a22;
                        b1_r      <= b1;
                        b2_r      <= b2;
                        x1_iter_r <= x1_init;
                        x2_iter_r <= x2_init;
                        state     <= ST_CALC;
                    end
                end

                ST_CALC: begin
                    x1_iter_r <= x1_next_w;
                    x2_iter_r <= x2_next_w;

                    if (iter_count == (ITERATIONS-1)) begin
                        x1    <= selected_x1_w;
                        x2    <= selected_x2_w;
                        ready <= 1'b1;
                        state <= ST_DONE;
                    end else begin
                        iter_count <= iter_count + 16'd1;
                    end
                end

                ST_DONE: begin
                    ready <= 1'b1;
                    x1    <= x1;
                    x2    <= x2;
                    state <= ST_DONE;
                end

                default: begin
                    state <= ST_IDLE;
                    ready <= 1'b0;
                end
            endcase
        end
    end

endmodule