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

    wire        u_sign;
    wire [23:0] u_mant_a;
    wire [23:0] u_mant_b;
    wire signed [11:0] u_exp_a_eff;
    wire signed [11:0] u_exp_b_eff;
    wire        u_a_zero;
    wire        u_b_zero;
    wire        u_a_inf;
    wire        u_b_inf;
    wire        u_a_nan;
    wire        u_b_nan;

    wire        u_special;
    wire [31:0] u_special_result;

    fp_mult_unpack u_unpack (
        .a(a),
        .b(b),
        .sign(u_sign),
        .mant_a(u_mant_a),
        .mant_b(u_mant_b),
        .exp_a_eff(u_exp_a_eff),
        .exp_b_eff(u_exp_b_eff),
        .a_zero(u_a_zero),
        .b_zero(u_b_zero),
        .a_inf(u_a_inf),
        .b_inf(u_b_inf),
        .a_nan(u_a_nan),
        .b_nan(u_b_nan)
    );

    fp_mult_special u_special_cases (
        .sign(u_sign),
        .a_zero(u_a_zero),
        .b_zero(u_b_zero),
        .a_inf(u_a_inf),
        .b_inf(u_b_inf),
        .a_nan(u_a_nan),
        .b_nan(u_b_nan),
        .is_special(u_special),
        .special_result(u_special_result)
    );

    reg        s1_valid;
    reg        s1_sign;
    reg [23:0] s1_mant_a;
    reg [23:0] s1_mant_b;
    reg signed [11:0] s1_exp_a_eff;
    reg signed [11:0] s1_exp_b_eff;
    reg        s1_special;
    reg [31:0] s1_special_result;

    wire [47:0] m_product;
    wire signed [11:0] m_exp_sum;

    fp_mult_mul_exp u_mul_exp (
        .mant_a(s1_mant_a),
        .mant_b(s1_mant_b),
        .exp_a_eff(s1_exp_a_eff),
        .exp_b_eff(s1_exp_b_eff),
        .product(m_product),
        .exp_sum(m_exp_sum)
    );

    reg        s2_valid;
    reg        s2_sign;
    reg [47:0] s2_product;
    reg signed [11:0] s2_exp_sum;
    reg        s2_special;
    reg [31:0] s2_special_result;

    wire [23:0] n_sig;
    wire signed [11:0] n_exp;
    wire        n_guard;
    wire        n_round;
    wire        n_sticky;

    fp_mult_normalize u_normalize (
        .product(s2_product),
        .exp_in(s2_exp_sum),
        .sig(n_sig),
        .exp_out(n_exp),
        .guard_bit(n_guard),
        .round_bit(n_round),
        .sticky_bit(n_sticky)
    );

    reg        s3_valid;
    reg        s3_sign;
    reg [23:0] s3_sig;
    reg signed [11:0] s3_exp;
    reg        s3_guard;
    reg        s3_round;
    reg        s3_sticky;
    reg        s3_special;
    reg [31:0] s3_special_result;

    wire [23:0] r_mant;
    wire [7:0]  r_exp;
    wire        r_overflow;
    wire        r_underflow;

    fp_mult_round u_round (
        .sig(s3_sig),
        .exp_in(s3_exp),
        .guard_bit(s3_guard),
        .round_bit(s3_round),
        .sticky_bit(s3_sticky),
        .mant_out(r_mant),
        .exp_out(r_exp),
        .overflow(r_overflow),
        .underflow(r_underflow)
    );

    reg        s4_valid;
    reg        s4_sign;
    reg [23:0] s4_mant;
    reg [7:0]  s4_exp;
    reg        s4_overflow;
    reg        s4_underflow;
    reg        s4_special;
    reg [31:0] s4_special_result;

    wire [31:0] p_result;

    fp_mult_pack u_pack (
        .sign(s4_sign),
        .mant(s4_mant),
        .exp(s4_exp),
        .overflow(s4_overflow),
        .underflow(s4_underflow),
        .is_special(s4_special),
        .special_result(s4_special_result),
        .result(p_result)
    );

    reg [31:0] result_reg;
    reg        valid_out_reg;

    assign result = result_reg;
    assign valid_out = valid_out_reg;

    always @(posedge clk) begin
        if (rst) begin
            s1_valid <= 1'b0;
            s1_sign <= 1'b0;
            s1_mant_a <= 24'b0;
            s1_mant_b <= 24'b0;
            s1_exp_a_eff <= 12'sd0;
            s1_exp_b_eff <= 12'sd0;
            s1_special <= 1'b0;
            s1_special_result <= 32'b0;

            s2_valid <= 1'b0;
            s2_sign <= 1'b0;
            s2_product <= 48'b0;
            s2_exp_sum <= 12'sd0;
            s2_special <= 1'b0;
            s2_special_result <= 32'b0;

            s3_valid <= 1'b0;
            s3_sign <= 1'b0;
            s3_sig <= 24'b0;
            s3_exp <= 12'sd0;
            s3_guard <= 1'b0;
            s3_round <= 1'b0;
            s3_sticky <= 1'b0;
            s3_special <= 1'b0;
            s3_special_result <= 32'b0;

            s4_valid <= 1'b0;
            s4_sign <= 1'b0;
            s4_mant <= 24'b0;
            s4_exp <= 8'b0;
            s4_overflow <= 1'b0;
            s4_underflow <= 1'b0;
            s4_special <= 1'b0;
            s4_special_result <= 32'b0;

            result_reg <= 32'b0;
            valid_out_reg <= 1'b0;
        end else begin
            s1_valid <= valid_in;
            s1_sign <= u_sign;
            s1_mant_a <= u_mant_a;
            s1_mant_b <= u_mant_b;
            s1_exp_a_eff <= u_exp_a_eff;
            s1_exp_b_eff <= u_exp_b_eff;
            s1_special <= u_special;
            s1_special_result <= u_special_result;

            s2_valid <= s1_valid;
            s2_sign <= s1_sign;
            s2_product <= m_product;
            s2_exp_sum <= m_exp_sum;
            s2_special <= s1_special;
            s2_special_result <= s1_special_result;

            s3_valid <= s2_valid;
            s3_sign <= s2_sign;
            s3_sig <= n_sig;
            s3_exp <= n_exp;
            s3_guard <= n_guard;
            s3_round <= n_round;
            s3_sticky <= n_sticky;
            s3_special <= s2_special;
            s3_special_result <= s2_special_result;

            s4_valid <= s3_valid;
            s4_sign <= s3_sign;
            s4_mant <= r_mant;
            s4_exp <= r_exp;
            s4_overflow <= r_overflow;
            s4_underflow <= r_underflow;
            s4_special <= s3_special;
            s4_special_result <= s3_special_result;

            valid_out_reg <= s4_valid;
            if (s4_valid) begin
                result_reg <= p_result;
            end
        end
    end

endmodule