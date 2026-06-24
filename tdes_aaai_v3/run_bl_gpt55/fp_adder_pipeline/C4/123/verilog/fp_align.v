`timescale 1ns/1ps

module fp_align (
    input         a_sign,
    input         b_sign,
    input  [7:0]  a_exp,
    input  [7:0]  b_exp,
    input  [23:0] a_sig,
    input  [23:0] b_sig,
    output        sign_large,
    output        sign_small,
    output [7:0]  exp_large,
    output [26:0] sig_large_ext,
    output [26:0] sig_small_ext
);

    /*
     * For alignment purposes, IEEE-754 subnormal operands use the same
     * effective exponent as the smallest normal exponent.  Zero remains zero.
     */
    wire [7:0] a_exp_eff = ((a_exp == 8'd0) && (a_sig != 24'd0)) ? 8'd1 : a_exp;
    wire [7:0] b_exp_eff = ((b_exp == 8'd0) && (b_sig != 24'd0)) ? 8'd1 : b_exp;

    wire a_is_large =
        (a_exp_eff > b_exp_eff) ||
        ((a_exp_eff == b_exp_eff) && (a_sig >= b_sig));

    wire        large_sign = a_is_large ? a_sign     : b_sign;
    wire        small_sign = a_is_large ? b_sign     : a_sign;
    wire [7:0]  large_exp  = a_is_large ? a_exp_eff  : b_exp_eff;
    wire [7:0]  small_exp  = a_is_large ? b_exp_eff  : a_exp_eff;
    wire [23:0] large_sig  = a_is_large ? a_sig      : b_sig;
    wire [23:0] small_sig  = a_is_large ? b_sig      : a_sig;

    wire [7:0] exp_diff = large_exp - small_exp;

    assign sign_large    = large_sign;
    assign sign_small    = small_sign;
    assign exp_large     = large_exp;
    assign sig_large_ext = {large_sig, 3'b000};
    assign sig_small_ext = shift_right_jam_27(small_sig, exp_diff);

    function [26:0] shift_right_jam_27;
        input [23:0] sig;
        input [7:0]  shamt;

        reg [26:0] ext;
        reg [26:0] shifted;
        reg        sticky;
        integer    i;

        begin
            ext = {sig, 3'b000};

            if (shamt == 8'd0) begin
                shift_right_jam_27 = ext;
            end else if (shamt >= 8'd27) begin
                shift_right_jam_27 = {26'd0, |ext};
            end else begin
                shifted = ext >> shamt;
                sticky  = 1'b0;

                for (i = 0; i < 27; i = i + 1) begin
                    if (i < shamt)
                        sticky = sticky | ext[i];
                end

                shifted[0] = shifted[0] | sticky;
                shift_right_jam_27 = shifted;
            end
        end
    endfunction

endmodule