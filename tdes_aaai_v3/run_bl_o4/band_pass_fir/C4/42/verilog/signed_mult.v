module signed_mult #(
    parameter integer DATA_W  = 20,
    parameter integer COEFF_W = 16
) (
    input  wire signed [DATA_W-1:0]      data_in,
    input  wire signed [COEFF_W-1:0]     coeff,
    output wire signed [DATA_W+COEFF_W-1:0] product
);
    // Treat inputs as two's-complement signed values
    // Perform a full-width signed multiplication
    assign product = data_in * coeff;
endmodule