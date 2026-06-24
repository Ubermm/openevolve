`timescale 1ns/1ps

module newton_raphson_poly_fixedpoint #(
    parameter WIDTH = 16,
    parameter FRAC = 8,
    parameter MAX_ITER = 50,
    parameter VERIFY_TOL = 8
)(
    input clk,
    input rst,
    input start,
    input signed [WIDTH-1:0] x_init,
    input signed [WIDTH-1:0] coeff0,
    input signed [WIDTH-1:0] coeff1,
    input signed [WIDTH-1:0] coeff2,
    input signed [WIDTH-1:0] coeff3,
    output reg signed [WIDTH-1:0] root,
    output reg ready,
    output reg valid
);

    localparam EXT_WIDTH = WIDTH * 4;

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_CALC   = 2'd1;
    localparam [1:0] ST_VERIFY = 2'd2;
    localparam [1:0] ST_DONE   = 2'd3;

    reg [1:0] state;
    integer iter_count;

    reg signed [EXT_WIDTH-1:0] x_reg;
    reg signed [WIDTH-1:0] coeff0_reg;
    reg signed [WIDTH-1:0] coeff1_reg;
    reg signed [WIDTH-1:0] coeff2_reg;
    reg signed [WIDTH-1:0] coeff3_reg;

    wire signed [EXT_WIDTH-1:0] poly_value;
    wire signed [EXT_WIDTH-1:0] deriv_value;
    wire signed [EXT_WIDTH-1:0] x_next;
    wire signed [EXT_WIDTH-1:0] newton_delta;
    wire div_by_zero;

    wire signed [EXT_WIDTH-1:0] verify_tolerance;
    wire signed [WIDTH-1:0] packed_root;
    wire verify_valid;

    wire conv_poly_small;
    wire conv_delta_small;

    assign verify_tolerance = VERIFY_TOL;

    fixed_poly_eval_cubic #(
        .WIDTH(WIDTH),
        .FRAC(FRAC),
        .EXT_WIDTH(EXT_WIDTH)
    ) u_poly_eval (
        .x(x_reg),
        .coeff0(coeff0_reg),
        .coeff1(coeff1_reg),
        .coeff2(coeff2_reg),
        .coeff3(coeff3_reg),
        .p(poly_value)
    );

    fixed_poly_derivative_cubic #(
        .WIDTH(WIDTH),
        .FRAC(FRAC),
        .EXT_WIDTH(EXT_WIDTH)
    ) u_derivative_eval (
        .x(x_reg),
        .coeff1(coeff1_reg),
        .coeff2(coeff2_reg),
        .coeff3(coeff3_reg),
        .p_prime(deriv_value)
    );

    fixed_newton_update #(
        .FRAC(FRAC),
        .EXT_WIDTH(EXT_WIDTH)
    ) u_newton_update (
        .x(x_reg),
        .p_value(poly_value),
        .p_prime(deriv_value),
        .x_next(x_next),
        .delta(newton_delta),
        .div_by_zero(div_by_zero)
    );

    fixed_convergence_check #(
        .EXT_WIDTH(EXT_WIDTH)
    ) u_convergence_check (
        .p_value(poly_value),
        .delta(newton_delta),
        .tolerance(verify_tolerance),
        .poly_small(conv_poly_small),
        .delta_small(conv_delta_small)
    );

    fixed_root_pack #(
        .WIDTH(WIDTH),
        .EXT_WIDTH(EXT_WIDTH)
    ) u_root_pack (
        .x(x_reg),
        .root(packed_root)
    );

    fixed_root_verify #(
        .EXT_WIDTH(EXT_WIDTH)
    ) u_root_verify (
        .p_value(poly_value),
        .tolerance(verify_tolerance),
        .valid(verify_valid)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= ST_IDLE;
            iter_count <= 0;
            x_reg      <= {EXT_WIDTH{1'b0}};
            coeff0_reg <= {WIDTH{1'b0}};
            coeff1_reg <= {WIDTH{1'b0}};
            coeff2_reg <= {WIDTH{1'b0}};
            coeff3_reg <= {WIDTH{1'b0}};
            root       <= {WIDTH{1'b0}};
            ready      <= 1'b0;
            valid      <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    ready <= 1'b0;
                    valid <= 1'b0;
                    iter_count <= 0;

                    if (start) begin
                        x_reg <= {{(EXT_WIDTH-WIDTH){x_init[WIDTH-1]}}, x_init};
                        coeff0_reg <= coeff0;
                        coeff1_reg <= coeff1;
                        coeff2_reg <= coeff2;
                        coeff3_reg <= coeff3;
                        state <= ST_CALC;
                    end
                end

                ST_CALC: begin
                    x_reg <= x_next;

                    if (iter_count >= (MAX_ITER - 1)) begin
                        iter_count <= iter_count + 1;
                        state <= ST_VERIFY;
                    end else begin
                        iter_count <= iter_count + 1;
                        state <= ST_CALC;
                    end
                end

                ST_VERIFY: begin
                    root  <= packed_root;
                    valid <= verify_valid;
                    ready <= 1'b1;
                    state <= ST_DONE;
                end

                ST_DONE: begin
                    ready <= 1'b1;
                    valid <= valid;
                    root  <= root;
                    state <= ST_DONE;
                end

                default: begin
                    state <= ST_IDLE;
                    ready <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule