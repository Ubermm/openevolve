`timescale 1ns/1ps

module fp_unpack (
    input  [31:0] operand,
    output        sign,
    output [7:0]  exp_eff,
    output [23:0] sig,
    output        is_zero,
    output        is_inf,
    output        is_nan
);

wire [7:0]  exp_field;
wire [22:0] frac_field;
wire        exp_is_zero;
wire        exp_is_ones;
wire        frac_is_zero;

assign sign       = operand[31];
assign exp_field  = operand[30:23];
assign frac_field = operand[22:0];

assign exp_is_zero  = (exp_field == 8'h00);
assign exp_is_ones  = (exp_field == 8'hff);
assign frac_is_zero = (frac_field == 23'h000000);

assign is_zero = exp_is_zero && frac_is_zero;
assign is_inf  = exp_is_ones && frac_is_zero;
assign is_nan  = exp_is_ones && !frac_is_zero;

/*
 * Effective exponent:
 *   - Normal numbers use the encoded exponent.
 *   - Zero/subnormal numbers use exponent 1, corresponding to unbiased -126.
 *
 * Significand:
 *   - Normal numbers have an implicit leading 1.
 *   - Zero/subnormal numbers have an implicit leading 0.
 *   - INF/NaN retain an exponent of 255 and use a leading 1 here; downstream
 *     special-case logic should use is_inf/is_nan for result resolution.
 */
assign exp_eff = exp_is_zero ? 8'd1 : exp_field;
assign sig     = exp_is_zero ? {1'b0, frac_field} : {1'b1, frac_field};

endmodule