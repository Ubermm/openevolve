module fp_mult_unpack (
    input  [31:0] a,
    input  [31:0] b,
    output        sign,
    output [7:0]  exp_a,
    output [7:0]  exp_b,
    output [23:0] mant_a,
    output [23:0] mant_b,
    output        zero_a,
    output        zero_b,
    output        inf_a,
    output        inf_b,
    output        nan_a,
    output        nan_b,
    output        subnormal_a,
    output        subnormal_b
);

    wire        sign_a;
    wire        sign_b;
    wire [7:0]  exp_field_a;
    wire [7:0]  exp_field_b;
    wire [22:0] frac_a;
    wire [22:0] frac_b;

    assign sign_a      = a[31];
    assign sign_b      = b[31];
    assign exp_field_a = a[30:23];
    assign exp_field_b = b[30:23];
    assign frac_a      = a[22:0];
    assign frac_b      = b[22:0];

    assign sign = sign_a ^ sign_b;

    assign zero_a      = (exp_field_a == 8'h00) && (frac_a == 23'h000000);
    assign zero_b      = (exp_field_b == 8'h00) && (frac_b == 23'h000000);

    assign subnormal_a = (exp_field_a == 8'h00) && (frac_a != 23'h000000);
    assign subnormal_b = (exp_field_b == 8'h00) && (frac_b != 23'h000000);

    assign inf_a       = (exp_field_a == 8'hff) && (frac_a == 23'h000000);
    assign inf_b       = (exp_field_b == 8'hff) && (frac_b == 23'h000000);

    assign nan_a       = (exp_field_a == 8'hff) && (frac_a != 23'h000000);
    assign nan_b       = (exp_field_b == 8'hff) && (frac_b != 23'h000000);

    /*
     * For normal numbers, prepend the implicit leading 1.
     * For zero and subnormal numbers, the leading bit is 0.
     */
    assign mant_a = (exp_field_a == 8'h00) ? {1'b0, frac_a} : {1'b1, frac_a};
    assign mant_b = (exp_field_b == 8'h00) ? {1'b0, frac_b} : {1'b1, frac_b};

    /*
     * Forward the exponent used by the arithmetic pipeline.
     * Subnormal operands have an effective exponent of -126, which corresponds
     * to biased exponent 1 when the downstream exponent adder subtracts bias.
     */
    assign exp_a = subnormal_a ? 8'h01 : exp_field_a;
    assign exp_b = subnormal_b ? 8'h01 : exp_field_b;

endmodule