`timescale 1ns/1ps
module fp_mult_pipeline #(
    parameter LATENCY = 5
) (
    input clk,
    input rst,
    input [31:0] a,
    input [31:0] b,
    input valid_in,
    output [31:0] result,
    output valid_out
);

    // Pipeline valid signals
    reg [LATENCY:0] valid_pipe;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            valid_pipe <= {LATENCY+1{1'b0}};
        end else begin
            valid_pipe[0] <= valid_in;
            for (i = 0; i < LATENCY; i = i + 1)
                valid_pipe[i+1] <= valid_pipe[i];
        end
    end
    assign valid_out = valid_pipe[LATENCY];

    // Stage 1: Unpack operands
    // Registers
    reg        S1_sign_a, S1_sign_b;
    reg [7:0]  S1_exp_a, S1_exp_b;
    reg [23:0] S1_mant_a, S1_mant_b;
    reg        S1_zero_a, S1_inf_a, S1_nan_a, S1_sub_a;
    reg        S1_zero_b, S1_inf_b, S1_nan_b, S1_sub_b;

    wire        U1_sign_a, U1_sign_b;
    wire [7:0]  U1_exp_a, U1_exp_b;
    wire [23:0] U1_mant_a, U1_mant_b;
    wire        U1_zero_a, U1_inf_a, U1_nan_a, U1_sub_a;
    wire        U1_zero_b, U1_inf_b, U1_nan_b, U1_sub_b;

    fp_unpack UNP_A(.in(a),
                    .sign(U1_sign_a), .exp(U1_exp_a),
                    .mant(U1_mant_a),
                    .is_zero(U1_zero_a), .is_inf(U1_inf_a),
                    .is_nan(U1_nan_a), .is_subnormal(U1_sub_a));
    fp_unpack UNP_B(.in(b),
                    .sign(U1_sign_b), .exp(U1_exp_b),
                    .mant(U1_mant_b),
                    .is_zero(U1_zero_b), .is_inf(U1_inf_b),
                    .is_nan(U1_nan_b), .is_subnormal(U1_sub_b));

    always @(posedge clk) begin
        if (rst) begin
            {S1_sign_a, S1_exp_a, S1_mant_a,
             S1_zero_a, S1_inf_a, S1_nan_a, S1_sub_a} <= 0;
            {S1_sign_b, S1_exp_b, S1_mant_b,
             S1_zero_b, S1_inf_b, S1_nan_b, S1_sub_b} <= 0;
        end else begin
            S1_sign_a <= U1_sign_a; S1_exp_a <= U1_exp_a;
            S1_mant_a <= U1_mant_a; S1_zero_a <= U1_zero_a;
            S1_inf_a  <= U1_inf_a;  S1_nan_a  <= U1_nan_a;
            S1_sub_a  <= U1_sub_a;
            S1_sign_b <= U1_sign_b; S1_exp_b <= U1_exp_b;
            S1_mant_b <= U1_mant_b; S1_zero_b <= U1_zero_b;
            S1_inf_b  <= U1_inf_b;  S1_nan_b  <= U1_nan_b;
            S1_sub_b  <= U1_sub_b;
        end
    end

    // Stage 2: Multiply mantissas and add exponents
    reg         S2_sign;
    reg signed [9:0] S2_exp_sum;
    reg [47:0]  S2_mant_prod;
    reg         S2_zero_a, S2_inf_a, S2_nan_a, S2_sub_a;
    reg         S2_zero_b, S2_inf_b, S2_nan_b, S2_sub_b;

    wire         M2_sign;
    wire signed [9:0] M2_exp_sum;
    wire [47:0]  M2_mant_prod;
    wire         M2_zero_a, M2_inf_a, M2_nan_a, M2_sub_a;
    wire         M2_zero_b, M2_inf_b, M2_nan_b, M2_sub_b;

    fp_mul_exp MUL_EXP (
        .sign_a(S1_sign_a), .exp_a(S1_exp_a), .mant_a(S1_mant_a),
        .is_zero_a(S1_zero_a), .is_inf_a(S1_inf_a), .is_nan_a(S1_nan_a), .is_subnormal_a(S1_sub_a),
        .sign_b(S1_sign_b), .exp_b(S1_exp_b), .mant_b(S1_mant_b),
        .is_zero_b(S1_zero_b), .is_inf_b(S1_inf_b), .is_nan_b(S1_nan_b), .is_subnormal_b(S1_sub_b),
        .sign_out(M2_sign),
        .exp_sum(M2_exp_sum),
        .mant_prod(M2_mant_prod),
        .is_zero_a_out(M2_zero_a), .is_inf_a_out(M2_inf_a), .is_nan_a_out(M2_nan_a), .is_subnormal_a_out(M2_sub_a),
        .is_zero_b_out(M2_zero_b), .is_inf_b_out(M2_inf_b), .is_nan_b_out(M2_nan_b), .is_subnormal_b_out(M2_sub_b)
    );

    always @(posedge clk) begin
        if (rst) begin
            {S2_sign, S2_exp_sum, S2_mant_prod,
             S2_zero_a, S2_inf_a, S2_nan_a, S2_sub_a,
             S2_zero_b, S2_inf_b, S2_nan_b, S2_sub_b} <= 0;
        end else begin
            S2_sign     <= M2_sign;
            S2_exp_sum  <= M2_exp_sum;
            S2_mant_prod<= M2_mant_prod;
            S2_zero_a   <= M2_zero_a;   S2_inf_a <= M2_inf_a;
            S2_nan_a    <= M2_nan_a;    S2_sub_a<= M2_sub_a;
            S2_zero_b   <= M2_zero_b;   S2_inf_b <= M2_inf_b;
            S2_nan_b    <= M2_nan_b;    S2_sub_b<= M2_sub_b;
        end
    end

    // Stage 3: Normalize
    reg         S3_sign;
    reg signed [9:0] S3_exp_norm;
    reg [23:0]  S3_mant_norm;
    reg         S3_guard, S3_round, S3_sticky;
    reg         S3_zero_a, S3_inf_a, S3_nan_a, S3_sub_a;
    reg         S3_zero_b, S3_inf_b, S3_nan_b, S3_sub_b;

    wire         N3_sign;
    wire signed [9:0] N3_exp_norm;
    wire [23:0]  N3_mant_norm;
    wire         N3_guard, N3_round, N3_sticky;
    wire         N3_zero_a, N3_inf_a, N3_nan_a, N3_sub_a;
    wire         N3_zero_b, N3_inf_b, N3_nan_b, N3_sub_b;

    fp_normalize NORMALIZE (
        .mant_prod(S2_mant_prod),
        .exp_sum(S2_exp_sum),
        .sign_in(S2_sign),
        .is_zero_a(S2_zero_a), .is_inf_a(S2_inf_a), .is_nan_a(S2_nan_a), .is_subnormal_a(S2_sub_a),
        .is_zero_b(S2_zero_b), .is_inf_b(S2_inf_b), .is_nan_b(S2_nan_b), .is_subnormal_b(S2_sub_b),
        .sign_out(N3_sign),
        .exp_norm(N3_exp_norm),
        .mant_norm(N3_mant_norm),
        .guard(N3_guard), .round(N3_round), .sticky(N3_sticky),
        .is_zero_a_out(N3_zero_a), .is_inf_a_out(N3_inf_a), .is_nan_a_out(N3_nan_a), .is_subnormal_a_out(N3_sub_a),
        .is_zero_b_out(N3_zero_b), .is_inf_b_out(N3_inf_b), .is_nan_b_out(N3_nan_b), .is_subnormal_b_out(N3_sub_b)
    );

    always @(posedge clk) begin
        if (rst) begin
            {S3_sign, S3_exp_norm, S3_mant_norm,
             S3_guard, S3_round, S3_sticky,
             S3_zero_a, S3_inf_a, S3_nan_a, S3_sub_a,
             S3_zero_b, S3_inf_b, S3_nan_b, S3_sub_b} <= 0;
        end else begin
            S3_sign     <= N3_sign;
            S3_exp_norm <= N3_exp_norm;
            S3_mant_norm<= N3_mant_norm;
            S3_guard    <= N3_guard;
            S3_round    <= N3_round;
            S3_sticky   <= N3_sticky;
            S3_zero_a   <= N3_zero_a;   S3_inf_a <= N3_inf_a;
            S3_nan_a    <= N3_nan_a;    S3_sub_a<= N3_sub_a;
            S3_zero_b   <= N3_zero_b;   S3_inf_b <= N3_inf_b;
            S3_nan_b    <= N3_nan_b;    S3_sub_b<= N3_sub_b;
        end
    end

    // Stage 4: Round
    reg         S4_sign;
    reg signed [9:0] S4_exp_round;
    reg [23:0]  S4_mant_round;
    reg         S4_zero_a, S4_inf_a, S4_nan_a, S4_sub_a;
    reg         S4_zero_b, S4_inf_b, S4_nan_b, S4_sub_b;

    wire         R4_sign;
    wire signed [9:0] R4_exp_round;
    wire [23:0]  R4_mant_round;
    wire         R4_zero_a, R4_inf_a, R4_nan_a, R4_sub_a;
    wire         R4_zero_b, R4_inf_b, R4_nan_b, R4_sub_b;

    fp_round ROUNDER (
        .sign_in(S3_sign),
        .exp_norm(S3_exp_norm),
        .mant_norm(S3_mant_norm),
        .guard(S3_guard), .round(S3_round), .sticky(S3_sticky),
        .is_zero_a(S3_zero_a), .is_inf_a(S3_inf_a), .is_nan_a(S3_nan_a), .is_subnormal_a(S3_sub_a),
        .is_zero_b(S3_zero_b), .is_inf_b(S3_inf_b), .is_nan_b(S3_nan_b), .is_subnormal_b(S3_sub_b),
        .sign_out(R4_sign),
        .exp_round(R4_exp_round),
        .mant_round(R4_mant_round),
        .is_zero_a_out(R4_zero_a), .is_inf_a_out(R4_inf_a), .is_nan_a_out(R4_nan_a), .is_subnormal_a_out(R4_sub_a),
        .is_zero_b_out(R4_zero_b), .is_inf_b_out(R4_inf_b), .is_nan_b_out(R4_nan_b), .is_subnormal_b_out(R4_sub_b)
    );

    always @(posedge clk) begin
        if (rst) begin
            {S4_sign, S4_exp_round, S4_mant_round,
             S4_zero_a, S4_inf_a, S4_nan_a, S4_sub_a,
             S4_zero_b, S4_inf_b, S4_nan_b, S4_sub_b} <= 0;
        end else begin
            S4_sign      <= R4_sign;
            S4_exp_round <= R4_exp_round;
            S4_mant_round<= R4_mant_round;
            S4_zero_a    <= R4_zero_a;   S4_inf_a <= R4_inf_a;
            S4_nan_a     <= R4_nan_a;    S4_sub_a<= R4_sub_a;
            S4_zero_b    <= R4_zero_b;   S4_inf_b <= R4_inf_b;
            S4_nan_b     <= R4_nan_b;    S4_sub_b<= R4_sub_b;
        end
    end

    // Stage 5: Pack result
    fp_pack PACKER (
        .sign(S4_sign),
        .exp_unbiased(S4_exp_round),
        .mantissa(S4_mant_round),
        .is_zero_a(S4_zero_a), .is_inf_a(S4_inf_a), .is_nan_a(S4_nan_a),
        .is_zero_b(S4_zero_b), .is_inf_b(S4_inf_b), .is_nan_b(S4_nan_b),
        .result(result)
    );

endmodule