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

    localparam EXP_WIDTH  = 8;
    localparam MANT_WIDTH = 23;
    localparam SIG_WIDTH  = 24;
    localparam PROD_WIDTH = 48;

    /*
     * Stage 1 combinational: unpack and early special classification
     */
    wire                  s1c_sign;
    wire [EXP_WIDTH-1:0]  s1c_exp_a;
    wire [EXP_WIDTH-1:0]  s1c_exp_b;
    wire [SIG_WIDTH-1:0]  s1c_mant_a;
    wire [SIG_WIDTH-1:0]  s1c_mant_b;
    wire                  s1c_zero_a;
    wire                  s1c_zero_b;
    wire                  s1c_inf_a;
    wire                  s1c_inf_b;
    wire                  s1c_nan_a;
    wire                  s1c_nan_b;
    wire                  s1c_subnormal_a;
    wire                  s1c_subnormal_b;

    fp_mult_unpack u_unpack (
        .a(a),
        .b(b),
        .sign(s1c_sign),
        .exp_a(s1c_exp_a),
        .exp_b(s1c_exp_b),
        .mant_a(s1c_mant_a),
        .mant_b(s1c_mant_b),
        .zero_a(s1c_zero_a),
        .zero_b(s1c_zero_b),
        .inf_a(s1c_inf_a),
        .inf_b(s1c_inf_b),
        .nan_a(s1c_nan_a),
        .nan_b(s1c_nan_b),
        .subnormal_a(s1c_subnormal_a),
        .subnormal_b(s1c_subnormal_b)
    );

    wire s1c_special_nan;
    wire s1c_special_inf;
    wire s1c_special_zero;
    wire s1c_special_sign;

    fp_mult_special u_special_s1 (
        .sign_in(s1c_sign),
        .zero_a(s1c_zero_a),
        .zero_b(s1c_zero_b),
        .inf_a(s1c_inf_a),
        .inf_b(s1c_inf_b),
        .nan_a(s1c_nan_a),
        .nan_b(s1c_nan_b),
        .special_nan(s1c_special_nan),
        .special_inf(s1c_special_inf),
        .special_zero(s1c_special_zero),
        .sign_out(s1c_special_sign)
    );

    /*
     * Pipeline registers
     */
    reg v1, v2, v3, v4, v5;

    reg                  s1_sign;
    reg [EXP_WIDTH-1:0]  s1_exp_a;
    reg [EXP_WIDTH-1:0]  s1_exp_b;
    reg [SIG_WIDTH-1:0]  s1_mant_a;
    reg [SIG_WIDTH-1:0]  s1_mant_b;
    reg                  s1_special_nan;
    reg                  s1_special_inf;
    reg                  s1_special_zero;

    reg                  s2_sign;
    reg                  s2_special_nan;
    reg                  s2_special_inf;
    reg                  s2_special_zero;
    reg [PROD_WIDTH-1:0] s2_product;
    reg signed [10:0]    s2_exp_pre;

    reg                  s3_sign;
    reg                  s3_special_nan;
    reg                  s3_special_inf;
    reg                  s3_special_zero;
    reg signed [10:0]    s3_exp_rounded;
    reg [MANT_WIDTH-1:0] s3_frac_rounded;
    reg                  s3_product_zero;

    reg                  s4_sign;
    reg                  s4_special_nan;
    reg                  s4_special_inf;
    reg                  s4_special_zero;
    reg signed [10:0]    s4_exp_rounded;
    reg [MANT_WIDTH-1:0] s4_frac_rounded;
    reg                  s4_overflow;
    reg                  s4_underflow;

    reg [31:0] result_reg;

    /*
     * Stage 2 combinational: significand multiply and exponent addition
     */
    wire [PROD_WIDTH-1:0] s2c_product;
    wire signed [10:0]    s2c_exp_pre;

    fp_mult_mul_exp u_mul_exp (
        .exp_a(s1_exp_a),
        .exp_b(s1_exp_b),
        .mant_a(s1_mant_a),
        .mant_b(s1_mant_b),
        .product(s2c_product),
        .exp_pre(s2c_exp_pre)
    );

    /*
     * Stage 3 combinational: normalize and round-to-nearest-even
     */
    wire signed [10:0]    s3c_exp_rounded;
    wire [MANT_WIDTH-1:0] s3c_frac_rounded;
    wire                  s3c_product_zero;

    fp_mult_normalize_round u_normalize_round (
        .product(s2_product),
        .exp_pre(s2_exp_pre),
        .exp_rounded(s3c_exp_rounded),
        .frac_rounded(s3c_frac_rounded),
        .product_zero(s3c_product_zero)
    );

    /*
     * Stage 4 combinational: overflow / underflow status
     */
    wire s4c_overflow;
    wire s4c_underflow;

    fp_mult_status u_status (
        .special_nan(s3_special_nan),
        .special_inf(s3_special_inf),
        .special_zero(s3_special_zero),
        .product_zero(s3_product_zero),
        .exp_rounded(s3_exp_rounded),
        .overflow(s4c_overflow),
        .underflow(s4c_underflow)
    );

    /*
     * Stage 5 combinational: final IEEE-754 packing
     */
    wire [31:0] s5c_result;

    fp_mult_pack u_pack (
        .sign(s4_sign),
        .special_nan(s4_special_nan),
        .special_inf(s4_special_inf),
        .special_zero(s4_special_zero),
        .overflow(s4_overflow),
        .underflow(s4_underflow),
        .exp_rounded(s4_exp_rounded),
        .frac_rounded(s4_frac_rounded),
        .result(s5c_result)
    );

    always @(posedge clk) begin
        if (rst) begin
            v1 <= 1'b0;
            v2 <= 1'b0;
            v3 <= 1'b0;
            v4 <= 1'b0;
            v5 <= 1'b0;

            s1_sign <= 1'b0;
            s1_exp_a <= 8'd0;
            s1_exp_b <= 8'd0;
            s1_mant_a <= 24'd0;
            s1_mant_b <= 24'd0;
            s1_special_nan <= 1'b0;
            s1_special_inf <= 1'b0;
            s1_special_zero <= 1'b0;

            s2_sign <= 1'b0;
            s2_special_nan <= 1'b0;
            s2_special_inf <= 1'b0;
            s2_special_zero <= 1'b0;
            s2_product <= 48'd0;
            s2_exp_pre <= 11'sd0;

            s3_sign <= 1'b0;
            s3_special_nan <= 1'b0;
            s3_special_inf <= 1'b0;
            s3_special_zero <= 1'b0;
            s3_exp_rounded <= 11'sd0;
            s3_frac_rounded <= 23'd0;
            s3_product_zero <= 1'b0;

            s4_sign <= 1'b0;
            s4_special_nan <= 1'b0;
            s4_special_inf <= 1'b0;
            s4_special_zero <= 1'b0;
            s4_exp_rounded <= 11'sd0;
            s4_frac_rounded <= 23'd0;
            s4_overflow <= 1'b0;
            s4_underflow <= 1'b0;

            result_reg <= 32'd0;
        end else begin
            v1 <= valid_in;
            v2 <= v1;
            v3 <= v2;
            v4 <= v3;
            v5 <= v4;

            s1_sign <= s1c_special_sign;
            s1_exp_a <= s1c_exp_a;
            s1_exp_b <= s1c_exp_b;
            s1_mant_a <= s1c_mant_a;
            s1_mant_b <= s1c_mant_b;
            s1_special_nan <= s1c_special_nan;
            s1_special_inf <= s1c_special_inf;
            s1_special_zero <= s1c_special_zero;

            s2_sign <= s1_sign;
            s2_special_nan <= s1_special_nan;
            s2_special_inf <= s1_special_inf;
            s2_special_zero <= s1_special_zero;
            s2_product <= s2c_product;
            s2_exp_pre <= s2c_exp_pre;

            s3_sign <= s2_sign;
            s3_special_nan <= s2_special_nan;
            s3_special_inf <= s2_special_inf;
            s3_special_zero <= s2_special_zero;
            s3_exp_rounded <= s3c_exp_rounded;
            s3_frac_rounded <= s3c_frac_rounded;
            s3_product_zero <= s3c_product_zero;

            s4_sign <= s3_sign;
            s4_special_nan <= s3_special_nan;
            s4_special_inf <= s3_special_inf;
            s4_special_zero <= s3_special_zero;
            s4_exp_rounded <= s3_exp_rounded;
            s4_frac_rounded <= s3_frac_rounded;
            s4_overflow <= s4c_overflow;
            s4_underflow <= s4c_underflow;

            /*
             * Hold result when no valid stage-4 data is being packed.
             * This matches streaming operation and keeps result stable after valid_out.
             */
            if (v4) begin
                result_reg <= s5c_result;
            end
        end
    end

    assign result = result_reg;
    assign valid_out = v5;

endmodule