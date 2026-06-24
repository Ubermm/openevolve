module fp_unpack(
    input  wire [31:0] in,
    output wire        sign,
    output wire [7:0]  exp,
    output wire [23:0] mant,
    output wire        is_zero,
    output wire        is_inf,
    output wire        is_nan,
    output wire        is_subnormal
);

    // raw fields
    wire [7:0]  exp_field = in[30:23];
    wire [22:0] frac      = in[22:0];

    // sign bit
    assign sign = in[31];

    // special‐case detection
    assign is_zero      = (exp_field == 8'd0)  && (frac == 23'd0);
    assign is_subnormal = (exp_field == 8'd0)  && (frac != 23'd0);
    assign is_inf       = (exp_field == 8'hFF) && (frac == 23'd0);
    assign is_nan       = (exp_field == 8'hFF) && (frac != 23'd0);

    // exponent: for normals pass through, for subnormals treat as 1, zero stays 0
    assign exp = is_zero      ? 8'd0 :
                 is_subnormal ? 8'd1 :
                 exp_field;

    // mantissa: implicit 1 for normals, 0 for subnormals, zero cleared
    assign mant = is_zero      ? 24'd0 :
                  is_subnormal ? {1'b0, frac} :
                                 {1'b1, frac};

endmodule