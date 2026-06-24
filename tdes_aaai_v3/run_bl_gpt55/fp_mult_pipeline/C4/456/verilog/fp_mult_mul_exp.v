module fp_mult_mul_exp (
    input  [7:0]  exp_a,
    input  [7:0]  exp_b,
    input  [23:0] mant_a,
    input  [23:0] mant_b,
    output [47:0] product,
    output signed [10:0] exp_pre
);

    wire [8:0] exp_eff_a;
    wire [8:0] exp_eff_b;

    assign exp_eff_a = (exp_a == 8'd0) ? 9'd1 : {1'b0, exp_a};
    assign exp_eff_b = (exp_b == 8'd0) ? 9'd1 : {1'b0, exp_b};

    assign product = mant_a * mant_b;

    assign exp_pre = $signed({2'b00, exp_eff_a}) +
                     $signed({2'b00, exp_eff_b}) -
                     11'sd127;

endmodule