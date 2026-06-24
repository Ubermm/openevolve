`timescale 1ns/1ps

module fp_mult_round (
    input  [23:0] mant_pre,
    input         guard_bit,
    input         round_bit,
    input         sticky_bit,
    input  signed [10:0] exp_norm,
    output [23:0] mant_round,
    output signed [10:0] exp_round
);

    wire round_increment;
    wire [24:0] mant_sum;

    /*
     * Round to nearest, ties to even:
     * - If guard bit is 0, truncate.
     * - If guard bit is 1 and any lower bit is 1, round up.
     * - If exactly halfway, round up only when mantissa LSB is 1,
     *   producing an even result.
     */
    assign round_increment = guard_bit & (round_bit | sticky_bit | mant_pre[0]);

    assign mant_sum = {1'b0, mant_pre} + {24'b0, round_increment};

    /*
     * If rounding overflows the 24-bit significand, renormalize by
     * shifting right one bit and incrementing the exponent.
     */
    assign mant_round = mant_sum[24] ? mant_sum[24:1] : mant_sum[23:0];
    assign exp_round  = mant_sum[24] ? (exp_norm + 11'sd1) : exp_norm;

endmodule