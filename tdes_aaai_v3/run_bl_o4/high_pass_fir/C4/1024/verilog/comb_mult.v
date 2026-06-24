module comb_mult #(
    parameter integer DATA_W  = 0,
    parameter integer COEFF_W = 0,
    // signed coefficient of width COEFF_W
    parameter signed [COEFF_W-1:0] COEFF = 'd0
) (
    input  wire signed [DATA_W-1:0]         data_in,
    output wire signed [DATA_W+COEFF_W-1:0] mult_out
);
    // Extend both operands to full output width and perform signed multiply
    wire signed [DATA_W+COEFF_W-1:0] data_ext  = {{COEFF_W{data_in[DATA_W-1]}}, data_in};
    wire signed [DATA_W+COEFF_W-1:0] coeff_ext = {{DATA_W{COEFF[COEFF_W-1]}}, COEFF};
    assign mult_out = data_ext * coeff_ext;
endmodule