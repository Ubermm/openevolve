module mult_by_coeff #(
    parameter DATA_W  = 20,
    parameter COEFF_W = 16
) (
    input  wire signed [DATA_W-1:0]      data_in,
    input  wire signed [COEFF_W-1:0]     coeff_in,
    output wire signed [DATA_W+COEFF_W-1:0] product_out
);
    // Combinational signed multiplier
    assign product_out = data_in * coeff_in;
endmodule