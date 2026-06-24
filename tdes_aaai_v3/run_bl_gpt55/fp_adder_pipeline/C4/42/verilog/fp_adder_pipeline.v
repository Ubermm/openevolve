`timescale 1ns/1ps

module fp_adder_pipeline #(
    parameter LATENCY = 5
) (
    input clk,
    input rst,
    input [31:0] a,
    input [31:0] b,
    input add_sub,
    input valid_in,
    output [31:0] result,
    output valid_out
);

    /* ---------------- Stage 1 combinational: unpack/special detect ---------------- */

    wire        u_sign_a, u_sign_b;
    wire [7:0]  u_exp_a, u_exp_b;
    wire [22:0] u_frac_a, u_frac_b;
    wire [23:0] u_sig_a, u_sig_b;
    wire        u_zero_a, u_zero_b;
    wire        u_inf_a, u_inf_b;
    wire        u_nan_a, u_nan_b;

    fp_unpack u_unpack (
        .a(a),
        .b(b),
        .add_sub(add_sub),
        .sign_a(u_sign_a),
        .sign_b(u_sign_b),
        .exp_a(u_exp_a),
        .exp_b(u_exp_b),
        .frac_a(u_frac_a),
        .frac_b(u_frac_b),
        .sig_a(u_sig_a),
        .sig_b(u_sig_b),
        .is_zero_a(u_zero_a),
        .is_zero_b(u_zero_b),
        .is_inf_a(u_inf_a),
        .is_inf_b(u_inf_b),
        .is_nan_a(u_nan_a),
        .is_nan_b(u_nan_b)
    );

    wire        sp_valid_c;
    wire [31:0] sp_result_c;

    fp_special_cases u_special (
        .sign_a(u_sign_a),
        .sign_b(u_sign_b),
        .exp_a(u_exp_a),
        .exp_b(u_exp_b),
        .frac_a(u_frac_a),
        .frac_b(u_frac_b),
        .is_zero_a(u_zero_a),
        .is_zero_b(u_zero_b),
        .is_inf_a(u_inf_a),
        .is_inf_b(u_inf_b),
        .is_nan_a(u_nan_a),
        .is_nan_b(u_nan_b),
        .special_valid(sp_valid_c),
        .special_result(sp_result_c)
    );

    reg        s1_sign_a, s1_sign_b;
    reg [7:0]  s1_exp_a, s1_exp_b;
    reg [23:0] s1_sig_a, s1_sig_b;
    reg        s1_special_valid;
    reg [31:0] s1_special_result;

    /* ---------------- Stage 2 combinational: align ---------------- */

    wire        al_sign_large_c, al_sign_small_c;
    wire [8:0]  al_exp_large_c;
    wire [26:0] al_mant_large_c, al_mant_small_c;

    fp_align u_align (
        .sign_a(s1_sign_a),
        .sign_b(s1_sign_b),
        .exp_a(s1_exp_a),
        .exp_b(s1_exp_b),
        .sig_a(s1_sig_a),
        .sig_b(s1_sig_b),
        .sign_large(al_sign_large_c),
        .sign_small(al_sign_small_c),
        .exp_large(al_exp_large_c),
        .mant_large(al_mant_large_c),
        .mant_small(al_mant_small_c)
    );

    reg        s2_sign_large, s2_sign_small;
    reg [8:0]  s2_exp_large;
    reg [26:0] s2_mant_large, s2_mant_small;
    reg        s2_special_valid;
    reg [31:0] s2_special_result;

    /* ---------------- Stage 3 combinational: add/sub significands ---------------- */

    wire        add_sign_c;
    wire [8:0]  add_exp_c;
    wire [27:0] add_mant_c;

    fp_addsub_sig u_addsub (
        .sign_large(s2_sign_large),
        .sign_small(s2_sign_small),
        .exp_large(s2_exp_large),
        .mant_large(s2_mant_large),
        .mant_small(s2_mant_small),
        .sign_out(add_sign_c),
        .exp_out(add_exp_c),
        .mant_sum(add_mant_c)
    );

    reg        s3_sign;
    reg [8:0]  s3_exp;
    reg [27:0] s3_mant;
    reg        s3_special_valid;
    reg [31:0] s3_special_result;

    /* ---------------- Stage 4 combinational: normalize ---------------- */

    wire        norm_sign_c;
    wire [8:0]  norm_exp_c;
    wire [26:0] norm_mant_c;
    wire        norm_zero_c;

    fp_normalize u_normalize (
        .sign_in(s3_sign),
        .exp_in(s3_exp),
        .mant_in(s3_mant),
        .sign_out(norm_sign_c),
        .exp_out(norm_exp_c),
        .mant_out(norm_mant_c),
        .is_zero(norm_zero_c)
    );

    reg        s4_sign;
    reg [8:0]  s4_exp;
    reg [26:0] s4_mant;
    reg        s4_zero;
    reg        s4_special_valid;
    reg [31:0] s4_special_result;

    /* ---------------- Stage 5 combinational: round/pack ---------------- */

    wire [31:0] pack_result_c;

    fp_round_pack u_round_pack (
        .sign_in(s4_sign),
        .exp_in(s4_exp),
        .mant_in(s4_mant),
        .is_zero(s4_zero),
        .special_valid(s4_special_valid),
        .special_result(s4_special_result),
        .result(pack_result_c)
    );

    reg [31:0] result_core;
    reg [4:0]  valid_pipe;
    wire       valid_core;

    assign valid_core = valid_pipe[4];

    always @(posedge clk) begin
        if (rst) begin
            s1_sign_a <= 1'b0;
            s1_sign_b <= 1'b0;
            s1_exp_a <= 8'd0;
            s1_exp_b <= 8'd0;
            s1_sig_a <= 24'd0;
            s1_sig_b <= 24'd0;
            s1_special_valid <= 1'b0;
            s1_special_result <= 32'd0;

            s2_sign_large <= 1'b0;
            s2_sign_small <= 1'b0;
            s2_exp_large <= 9'd0;
            s2_mant_large <= 27'd0;
            s2_mant_small <= 27'd0;
            s2_special_valid <= 1'b0;
            s2_special_result <= 32'd0;

            s3_sign <= 1'b0;
            s3_exp <= 9'd0;
            s3_mant <= 28'd0;
            s3_special_valid <= 1'b0;
            s3_special_result <= 32'd0;

            s4_sign <= 1'b0;
            s4_exp <= 9'd0;
            s4_mant <= 27'd0;
            s4_zero <= 1'b1;
            s4_special_valid <= 1'b0;
            s4_special_result <= 32'd0;

            result_core <= 32'd0;
            valid_pipe <= 5'd0;
        end else begin
            valid_pipe <= {valid_pipe[3:0], valid_in};

            s1_sign_a <= u_sign_a;
            s1_sign_b <= u_sign_b;
            s1_exp_a <= u_exp_a;
            s1_exp_b <= u_exp_b;
            s1_sig_a <= u_sig_a;
            s1_sig_b <= u_sig_b;
            s1_special_valid <= sp_valid_c;
            s1_special_result <= sp_result_c;

            s2_sign_large <= al_sign_large_c;
            s2_sign_small <= al_sign_small_c;
            s2_exp_large <= al_exp_large_c;
            s2_mant_large <= al_mant_large_c;
            s2_mant_small <= al_mant_small_c;
            s2_special_valid <= s1_special_valid;
            s2_special_result <= s1_special_result;

            s3_sign <= add_sign_c;
            s3_exp <= add_exp_c;
            s3_mant <= add_mant_c;
            s3_special_valid <= s2_special_valid;
            s3_special_result <= s2_special_result;

            s4_sign <= norm_sign_c;
            s4_exp <= norm_exp_c;
            s4_mant <= norm_mant_c;
            s4_zero <= norm_zero_c;
            s4_special_valid <= s3_special_valid;
            s4_special_result <= s3_special_result;

            result_core <= pack_result_c;
        end
    end

    generate
        if (LATENCY > 5) begin : gen_extra_latency
            localparam EXTRA = LATENCY - 5;
            reg [31:0] result_extra [0:EXTRA-1];
            reg [EXTRA-1:0] valid_extra;
            integer i;

            always @(posedge clk) begin
                if (rst) begin
                    for (i = 0; i < EXTRA; i = i + 1) begin
                        result_extra[i] <= 32'd0;
                    end
                    valid_extra <= {EXTRA{1'b0}};
                end else begin
                    result_extra[0] <= result_core;
                    valid_extra[0] <= valid_core;
                    for (i = 1; i < EXTRA; i = i + 1) begin
                        result_extra[i] <= result_extra[i-1];
                        valid_extra[i] <= valid_extra[i-1];
                    end
                end
            end

            assign result = result_extra[EXTRA-1];
            assign valid_out = valid_extra[EXTRA-1];
        end else begin : gen_base_latency
            assign result = result_core;
            assign valid_out = valid_core;
        end
    endgenerate

endmodule