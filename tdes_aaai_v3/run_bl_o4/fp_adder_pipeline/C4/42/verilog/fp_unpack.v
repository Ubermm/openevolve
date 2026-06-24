module fp_unpack(
    input  [31:0] a,
    input  [31:0] b,
    output        sign_a,
    output        sign_b,
    output [7:0]  exp_a,
    output [7:0]  exp_b,
    output [23:0] frac_a,
    output [23:0] frac_b,
    output        is_zero_a,
    output        is_zero_b,
    output        is_inf_a,
    output        is_inf_b,
    output        is_nan_a,
    output        is_nan_b
);

    // Raw fields
    wire [7:0]  raw_exp_a  = a[30:23];
    wire [7:0]  raw_exp_b  = b[30:23];
    wire [22:0] raw_frac_a = a[22:0];
    wire [22:0] raw_frac_b = b[22:0];

    // Sign bits
    assign sign_a = a[31];
    assign sign_b = b[31];

    // Special-case detection
    assign is_zero_a = (raw_exp_a == 8'd0) && (raw_frac_a == 23'd0);
    assign is_zero_b = (raw_exp_b == 8'd0) && (raw_frac_b == 23'd0);
    assign is_inf_a  = (raw_exp_a == 8'hFF) && (raw_frac_a == 23'd0);
    assign is_inf_b  = (raw_exp_b == 8'hFF) && (raw_frac_b == 23'd0);
    assign is_nan_a  = (raw_exp_a == 8'hFF) && (raw_frac_a != 23'd0);
    assign is_nan_b  = (raw_exp_b == 8'hFF) && (raw_frac_b != 23'd0);

    // Exponent outputs (biased)
    assign exp_a = raw_exp_a;
    assign exp_b = raw_exp_b;

    // Build 24-bit significand with implicit leading bit:
    //   normal    → 1.<fraction>
    //   subnormal → 0.<fraction>
    //   zero      → all zeros
    //   inf/nan   → 1.<fraction> (handled later)
    assign frac_a = is_zero_a                ? 24'd0 :
                    (raw_exp_a == 8'd0)     ? {1'b0, raw_frac_a} :
                                             {1'b1, raw_frac_a};

    assign frac_b = is_zero_b                ? 24'd0 :
                    (raw_exp_b == 8'd0)     ? {1'b0, raw_frac_b} :
                                             {1'b1, raw_frac_b};

endmodule