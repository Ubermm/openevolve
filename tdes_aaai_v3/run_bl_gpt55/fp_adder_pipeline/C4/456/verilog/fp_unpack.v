module fp_unpack (
    input  [31:0] a,
    input  [31:0] b,
    input         add_sub,
    output        sign_a,
    output        sign_b_eff,
    output [7:0]  exp_a_eff,
    output [7:0]  exp_b_eff,
    output [23:0] sig_a,
    output [23:0] sig_b,
    output        is_zero_a,
    output        is_zero_b,
    output        is_inf_a,
    output        is_inf_b,
    output        is_nan_a,
    output        is_nan_b
);

    wire [7:0]  exp_a;
    wire [7:0]  exp_b;
    wire [22:0] frac_a;
    wire [22:0] frac_b;

    assign exp_a  = a[30:23];
    assign exp_b  = b[30:23];
    assign frac_a = a[22:0];
    assign frac_b = b[22:0];

    assign sign_a     = a[31];
    assign sign_b_eff = b[31] ^ add_sub;

    assign is_zero_a = (exp_a == 8'h00) && (frac_a == 23'h000000);
    assign is_zero_b = (exp_b == 8'h00) && (frac_b == 23'h000000);

    assign is_inf_a  = (exp_a == 8'hff) && (frac_a == 23'h000000);
    assign is_inf_b  = (exp_b == 8'hff) && (frac_b == 23'h000000);

    assign is_nan_a  = (exp_a == 8'hff) && (frac_a != 23'h000000);
    assign is_nan_b  = (exp_b == 8'hff) && (frac_b != 23'h000000);

    assign exp_a_eff = (exp_a == 8'h00) ? 8'h01 : exp_a;
    assign exp_b_eff = (exp_b == 8'h00) ? 8'h01 : exp_b;

    assign sig_a = (exp_a == 8'h00) ? {1'b0, frac_a} : {1'b1, frac_a};
    assign sig_b = (exp_b == 8'h00) ? {1'b0, frac_b} : {1'b1, frac_b};

endmodule