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

localparam EXTRA_LATENCY = (LATENCY > 5) ? (LATENCY - 5) : 0;

// -----------------------------------------------------------------------------
// Stage 1 combinational: unpack and special-case detect
// -----------------------------------------------------------------------------
wire        a_sign_w;
wire [7:0]  a_exp_w;
wire [23:0] a_sig_w;
wire        a_zero_w;
wire        a_inf_w;
wire        a_nan_w;

wire        b_sign_raw_w;
wire [7:0]  b_exp_w;
wire [23:0] b_sig_w;
wire        b_zero_w;
wire        b_inf_w;
wire        b_nan_w;

wire        b_sign_eff_w;
wire        special_w;
wire [31:0] special_result_w;

fp_unpack u_unpack_a (
    .operand(a),
    .sign(a_sign_w),
    .exp_eff(a_exp_w),
    .sig(a_sig_w),
    .is_zero(a_zero_w),
    .is_inf(a_inf_w),
    .is_nan(a_nan_w)
);

fp_unpack u_unpack_b (
    .operand(b),
    .sign(b_sign_raw_w),
    .exp_eff(b_exp_w),
    .sig(b_sig_w),
    .is_zero(b_zero_w),
    .is_inf(b_inf_w),
    .is_nan(b_nan_w)
);

assign b_sign_eff_w = b_sign_raw_w ^ add_sub;

fp_special_cases u_special_cases (
    .a_sign(a_sign_w),
    .b_sign(b_sign_eff_w),
    .a_is_nan(a_nan_w),
    .b_is_nan(b_nan_w),
    .a_is_inf(a_inf_w),
    .b_is_inf(b_inf_w),
    .is_special(special_w),
    .special_result(special_result_w)
);

// Stage 1 registers
reg        s1_valid;
reg        s1_a_sign;
reg        s1_b_sign;
reg [7:0]  s1_a_exp;
reg [7:0]  s1_b_exp;
reg [23:0] s1_a_sig;
reg [23:0] s1_b_sig;
reg        s1_special;
reg [31:0] s1_special_result;

// -----------------------------------------------------------------------------
// Stage 2 combinational: exponent alignment
// -----------------------------------------------------------------------------
wire        align_sign_large_w;
wire        align_sign_small_w;
wire [7:0]  align_exp_large_w;
wire [26:0] align_sig_large_w;
wire [26:0] align_sig_small_w;

fp_align u_align (
    .a_sign(s1_a_sign),
    .b_sign(s1_b_sign),
    .a_exp(s1_a_exp),
    .b_exp(s1_b_exp),
    .a_sig(s1_a_sig),
    .b_sig(s1_b_sig),
    .sign_large(align_sign_large_w),
    .sign_small(align_sign_small_w),
    .exp_large(align_exp_large_w),
    .sig_large_ext(align_sig_large_w),
    .sig_small_ext(align_sig_small_w)
);

// Stage 2 registers
reg        s2_valid;
reg        s2_sign_large;
reg        s2_sign_small;
reg [7:0]  s2_exp;
reg [26:0] s2_sig_large;
reg [26:0] s2_sig_small;
reg        s2_special;
reg [31:0] s2_special_result;

// -----------------------------------------------------------------------------
// Stage 3 combinational: add/sub aligned significands
// -----------------------------------------------------------------------------
wire        add_sign_w;
wire [27:0] add_sum_w;
wire        add_zero_w;

fp_significand_addsub u_addsub (
    .sign_large(s2_sign_large),
    .sign_small(s2_sign_small),
    .sig_large_ext(s2_sig_large),
    .sig_small_ext(s2_sig_small),
    .result_sign(add_sign_w),
    .sig_sum(add_sum_w),
    .is_zero(add_zero_w)
);

// Stage 3 registers
reg        s3_valid;
reg        s3_sign;
reg [7:0]  s3_exp;
reg [27:0] s3_sum;
reg        s3_zero;
reg        s3_special;
reg [31:0] s3_special_result;

// -----------------------------------------------------------------------------
// Stage 4 combinational: normalize
// -----------------------------------------------------------------------------
wire        norm_sign_w;
wire [8:0]  norm_exp_w;
wire [26:0] norm_sig_w;
wire        norm_zero_w;

fp_normalize u_normalize (
    .sign_in(s3_sign),
    .exp_in(s3_exp),
    .sig_sum(s3_sum),
    .zero_in(s3_zero),
    .sign_out(norm_sign_w),
    .exp_out(norm_exp_w),
    .sig_norm(norm_sig_w),
    .zero_out(norm_zero_w)
);

// Stage 4 registers
reg        s4_valid;
reg        s4_sign;
reg [8:0]  s4_exp;
reg [26:0] s4_sig;
reg        s4_zero;
reg        s4_special;
reg [31:0] s4_special_result;

// -----------------------------------------------------------------------------
// Stage 5 combinational: round and pack
// -----------------------------------------------------------------------------
wire [31:0] packed_result_w;
wire [31:0] core_result_w;

fp_round_pack u_round_pack (
    .sign(s4_sign),
    .exp_norm(s4_exp),
    .sig_norm(s4_sig),
    .is_zero(s4_zero),
    .result(packed_result_w)
);

assign core_result_w = s4_special ? s4_special_result : packed_result_w;

// Stage 5 output register
reg        s5_valid;
reg [31:0] s5_result;

// -----------------------------------------------------------------------------
// Main pipeline registers
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        s1_valid          <= 1'b0;
        s1_a_sign         <= 1'b0;
        s1_b_sign         <= 1'b0;
        s1_a_exp          <= 8'd0;
        s1_b_exp          <= 8'd0;
        s1_a_sig          <= 24'd0;
        s1_b_sig          <= 24'd0;
        s1_special        <= 1'b0;
        s1_special_result <= 32'd0;

        s2_valid          <= 1'b0;
        s2_sign_large     <= 1'b0;
        s2_sign_small     <= 1'b0;
        s2_exp            <= 8'd0;
        s2_sig_large      <= 27'd0;
        s2_sig_small      <= 27'd0;
        s2_special        <= 1'b0;
        s2_special_result <= 32'd0;

        s3_valid          <= 1'b0;
        s3_sign           <= 1'b0;
        s3_exp            <= 8'd0;
        s3_sum            <= 28'd0;
        s3_zero           <= 1'b1;
        s3_special        <= 1'b0;
        s3_special_result <= 32'd0;

        s4_valid          <= 1'b0;
        s4_sign           <= 1'b0;
        s4_exp            <= 9'd0;
        s4_sig            <= 27'd0;
        s4_zero           <= 1'b1;
        s4_special        <= 1'b0;
        s4_special_result <= 32'd0;

        s5_valid          <= 1'b0;
        s5_result         <= 32'd0;
    end else begin
        // Stage 1
        s1_valid          <= valid_in;
        s1_a_sign         <= a_sign_w;
        s1_b_sign         <= b_sign_eff_w;
        s1_a_exp          <= a_exp_w;
        s1_b_exp          <= b_exp_w;
        s1_a_sig          <= a_sig_w;
        s1_b_sig          <= b_sig_w;
        s1_special        <= special_w;
        s1_special_result <= special_result_w;

        // Stage 2
        s2_valid          <= s1_valid;
        s2_sign_large     <= align_sign_large_w;
        s2_sign_small     <= align_sign_small_w;
        s2_exp            <= align_exp_large_w;
        s2_sig_large      <= align_sig_large_w;
        s2_sig_small      <= align_sig_small_w;
        s2_special        <= s1_special;
        s2_special_result <= s1_special_result;

        // Stage 3
        s3_valid          <= s2_valid;
        s3_sign           <= add_sign_w;
        s3_exp            <= s2_exp;
        s3_sum            <= add_sum_w;
        s3_zero           <= add_zero_w;
        s3_special        <= s2_special;
        s3_special_result <= s2_special_result;

        // Stage 4
        s4_valid          <= s3_valid;
        s4_sign           <= norm_sign_w;
        s4_exp            <= norm_exp_w;
        s4_sig            <= norm_sig_w;
        s4_zero           <= norm_zero_w;
        s4_special        <= s3_special;
        s4_special_result <= s3_special_result;

        // Stage 5
        s5_valid          <= s4_valid;
        s5_result         <= core_result_w;
    end
end

generate
    if (EXTRA_LATENCY == 0) begin : gen_no_extra_latency
        assign result    = s5_result;
        assign valid_out = s5_valid;
    end else begin : gen_extra_latency
        reg [31:0] result_delay [0:EXTRA_LATENCY-1];
        reg [EXTRA_LATENCY-1:0] valid_delay;
        integer i;

        always @(posedge clk) begin
            if (rst) begin
                valid_delay <= {EXTRA_LATENCY{1'b0}};
                for (i = 0; i < EXTRA_LATENCY; i = i + 1) begin
                    result_delay[i] <= 32'd0;
                end
            end else begin
                valid_delay[0] <= s5_valid;
                result_delay[0] <= s5_result;
                for (i = 1; i < EXTRA_LATENCY; i = i + 1) begin
                    valid_delay[i] <= valid_delay[i-1];
                    result_delay[i] <= result_delay[i-1];
                end
            end
        end

        assign result    = result_delay[EXTRA_LATENCY-1];
        assign valid_out = valid_delay[EXTRA_LATENCY-1];
    end
endgenerate

endmodule