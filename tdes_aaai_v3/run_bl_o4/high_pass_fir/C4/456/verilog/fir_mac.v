module fir_mac #(
    parameter DATA_W = 20
) (
    input  wire signed [63:0]       sum_in,
    input  wire signed [DATA_W-1:0] data_in,
    input  wire signed [15:0]       coeff_in,
    output wire signed [63:0]       sum_out
);

    // Width of the raw multiplication result
    localparam MUL_W = DATA_W + 16;

    // Multiply data sample by coefficient (signed)
    wire signed [MUL_W-1:0] prod = data_in * coeff_in;

    // Sign-extend the product to 64 bits
    wire signed [63:0] prod_ext = {{(64-MUL_W){prod[MUL_W-1]}}, prod};

    // Accumulate into the running sum
    assign sum_out = sum_in + prod_ext;

endmodule