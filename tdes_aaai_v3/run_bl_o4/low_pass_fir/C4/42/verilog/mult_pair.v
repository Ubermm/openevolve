module mult_pair #(
    parameter integer DATA_W  = 20,
    parameter integer COEFF_W = 16
) (
    input  wire signed [DATA_W-1:0]  a,
    input  wire signed [DATA_W-1:0]  b,
    input  wire signed [COEFF_W-1:0] c,
    output wire signed [DATA_W+COEFF_W:0] p
);

    // Sum two DATA_W-bit signed operands into DATA_W+1 bits
    wire signed [DATA_W:0] sum_ab;
    assign sum_ab = a + b;

    // Multiply the sum by the COEFF_W-bit signed coefficient
    // Result width is (DATA_W+1) + COEFF_W = DATA_W+COEFF_W+1 bits
    assign p = sum_ab * c;

endmodule