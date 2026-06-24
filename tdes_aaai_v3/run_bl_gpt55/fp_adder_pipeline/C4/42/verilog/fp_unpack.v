module fp_unpack (
    input  [31:0] a,
    input  [31:0] b,
    input         add_sub,
    output        sign_a,
    output        sign_b,
    output [7:0]  exp_a,
    output [7:0]  exp_b,
    output [22:0] frac_a,
    output [22:0] frac_b,
    output [23:0] sig_a,
    output [23:0] sig_b,
    output        is_zero_a,
    output        is_zero_b,
    output        is_inf_a,
    output        is_inf_b,
    output        is_nan_a,
    output        is_nan_b
);

    assign sign_a = a[31];

    /*
     * Effective sign of operand B.
     * add_sub = 0: A + B  -> use B sign unchanged
     * add_sub = 1: A - B  -> invert B sign, equivalent to A + (-B)
     */
    assign sign_b = b[31] ^ add_sub;

    assign exp_a  = a[30:23];
    assign exp_b  = b[30:23];

    assign frac_a = a[22:0];
    assign frac_b = b[22:0];

    /*
     * IEEE-754 significand creation.
     * Normal numbers have an implicit leading 1.
     * Subnormal numbers and zeros have an implicit leading 0.
     */
    assign sig_a = (exp_a == 8'h00) ? {1'b0, frac_a} : {1'b1, frac_a};
    assign sig_b = (exp_b == 8'h00) ? {1'b0, frac_b} : {1'b1, frac_b};

    /*
     * IEEE-754 classifications based on raw exponent and fraction fields.
     */
    assign is_zero_a = (exp_a == 8'h00) && (frac_a == 23'h000000);
    assign is_zero_b = (exp_b == 8'h00) && (frac_b == 23'h000000);

    assign is_inf_a  = (exp_a == 8'hff) && (frac_a == 23'h000000);
    assign is_inf_b  = (exp_b == 8'hff) && (frac_b == 23'h000000);

    assign is_nan_a  = (exp_a == 8'hff) && (frac_a != 23'h000000);
    assign is_nan_b  = (exp_b == 8'hff) && (frac_b != 23'h000000);

endmodule