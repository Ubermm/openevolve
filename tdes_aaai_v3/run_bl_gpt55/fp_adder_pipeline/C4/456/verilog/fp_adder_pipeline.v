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

localparam PIPE_DEPTH = (LATENCY < 1) ? 1 : LATENCY;

wire        ua_sign_a;
wire        ua_sign_b;
wire [7:0]  ua_exp_a;
wire [7:0]  ua_exp_b;
wire [23:0] ua_sig_a;
wire [23:0] ua_sig_b;
wire        ua_zero_a;
wire        ua_zero_b;
wire        ua_inf_a;
wire        ua_inf_b;
wire        ua_nan_a;
wire        ua_nan_b;

wire        sp_valid;
wire [31:0] sp_result;

wire        al_sign_large;
wire        al_sign_small;
wire [7:0]  al_exp_large;
wire [27:0] al_sig_large;
wire [27:0] al_sig_small;

wire        as_sign;
wire [7:0]  as_exp;
wire [28:0] as_mag;

wire        nm_sign;
wire [8:0]  nm_exp;
wire [27:0] nm_sig;

wire [31:0] comb_result;

fp_unpack u_unpack (
    .a(a),
    .b(b),
    .add_sub(add_sub),
    .sign_a(ua_sign_a),
    .sign_b_eff(ua_sign_b),
    .exp_a_eff(ua_exp_a),
    .exp_b_eff(ua_exp_b),
    .sig_a(ua_sig_a),
    .sig_b(ua_sig_b),
    .is_zero_a(ua_zero_a),
    .is_zero_b(ua_zero_b),
    .is_inf_a(ua_inf_a),
    .is_inf_b(ua_inf_b),
    .is_nan_a(ua_nan_a),
    .is_nan_b(ua_nan_b)
);

fp_special u_special (
    .a(a),
    .b(b),
    .sign_a(ua_sign_a),
    .sign_b_eff(ua_sign_b),
    .is_zero_a(ua_zero_a),
    .is_zero_b(ua_zero_b),
    .is_inf_a(ua_inf_a),
    .is_inf_b(ua_inf_b),
    .is_nan_a(ua_nan_a),
    .is_nan_b(ua_nan_b),
    .special_valid(sp_valid),
    .special_result(sp_result)
);

fp_align u_align (
    .sign_a(ua_sign_a),
    .sign_b_eff(ua_sign_b),
    .exp_a_eff(ua_exp_a),
    .exp_b_eff(ua_exp_b),
    .sig_a(ua_sig_a),
    .sig_b(ua_sig_b),
    .sign_large(al_sign_large),
    .sign_small(al_sign_small),
    .exp_large(al_exp_large),
    .sig_large(al_sig_large),
    .sig_small(al_sig_small)
);

fp_addsub_significands u_addsub (
    .sign_large(al_sign_large),
    .sign_small(al_sign_small),
    .exp_large(al_exp_large),
    .sig_large(al_sig_large),
    .sig_small(al_sig_small),
    .result_sign(as_sign),
    .result_exp(as_exp),
    .result_mag(as_mag)
);

fp_normalize u_normalize (
    .sign_in(as_sign),
    .exp_in(as_exp),
    .mag_in(as_mag),
    .sign_out(nm_sign),
    .exp_out(nm_exp),
    .sig_out(nm_sig)
);

fp_round_pack u_round_pack (
    .special_valid(sp_valid),
    .special_result(sp_result),
    .sign_in(nm_sign),
    .exp_in(nm_exp),
    .sig_in(nm_sig),
    .result(comb_result)
);

reg [31:0] result_pipe [0:PIPE_DEPTH-1];
reg        valid_pipe  [0:PIPE_DEPTH-1];

integer i;

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < PIPE_DEPTH; i = i + 1) begin
            result_pipe[i] <= 32'h00000000;
            valid_pipe[i]  <= 1'b0;
        end
    end else begin
        result_pipe[0] <= comb_result;
        valid_pipe[0]  <= valid_in;

        for (i = 1; i < PIPE_DEPTH; i = i + 1) begin
            result_pipe[i] <= result_pipe[i-1];
            valid_pipe[i]  <= valid_pipe[i-1];
        end
    end
end

assign result    = result_pipe[PIPE_DEPTH-1];
assign valid_out = valid_pipe[PIPE_DEPTH-1];

endmodule