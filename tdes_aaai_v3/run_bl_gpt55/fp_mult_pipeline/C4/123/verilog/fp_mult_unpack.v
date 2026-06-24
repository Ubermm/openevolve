module fp_mult_unpack (
    input  [31:0] a,
    input  [31:0] b,
    output        sign,
    output [23:0] mant_a,
    output [23:0] mant_b,
    output signed [11:0] exp_a_eff,
    output signed [11:0] exp_b_eff,
    output        a_zero,
    output        b_zero,
    output        a_inf,
    output        b_inf,
    output        a_nan,
    output        b_nan
);

    wire [7:0]  exp_a;
    wire [7:0]  exp_b;
    wire [22:0] frac_a;
    wire [22:0] frac_b;

    assign exp_a  = a[30:23];
    assign exp_b  = b[30:23];
    assign frac_a = a[22:0];
    assign frac_b = b[22:0];

    assign sign = a[31] ^ b[31];

    assign a_zero = (exp_a == 8'h00) && (frac_a == 23'h000000);
    assign b_zero = (exp_b == 8'h00) && (frac_b == 23'h000000);

    assign a_inf  = (exp_a == 8'hFF) && (frac_a == 23'h000000);
    assign b_inf  = (exp_b == 8'hFF) && (frac_b == 23'h000000);

    assign a_nan  = (exp_a == 8'hFF) && (frac_a != 23'h000000);
    assign b_nan  = (exp_b == 8'hFF) && (frac_b != 23'h000000);

    assign mant_a = (exp_a == 8'h00) ? {1'b0, frac_a} : {1'b1, frac_a};
    assign mant_b = (exp_b == 8'h00) ? {1'b0, frac_b} : {1'b1, frac_b};

    assign exp_a_eff = (exp_a == 8'h00) ? 12'sd1 : $signed({4'b0000, exp_a});
    assign exp_b_eff = (exp_b == 8'h00) ? 12'sd1 : $signed({4'b0000, exp_b});

endmodule