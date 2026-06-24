module mult_add_stage #(
    parameter DATA_W  = 20,
    parameter COEFF_W = 16,
    parameter ACC_W   = 64
) (
    input  wire signed [DATA_W-1:0]  data_in,
    input  wire signed [ACC_W-1:0]   sum_in,
    input  wire signed [COEFF_W-1:0] coeff,
    output wire signed [DATA_W-1:0]  data_out,
    output wire signed [ACC_W-1:0]   sum_out
);

    // Multiply data_in by coeff
    wire signed [DATA_W+COEFF_W-1:0] mac_product;
    assign mac_product = data_in * coeff;

    // Sign-extend product to accumulator width
    wire signed [ACC_W-1:0] product_ext;
    assign product_ext = {{(ACC_W-(DATA_W+COEFF_W)){mac_product[DATA_W+COEFF_W-1]}}, mac_product};

    // Pass the sample through unchanged for downstream pipeline
    assign data_out = data_in;

    // Accumulate the extended product with the incoming sum
    assign sum_out = sum_in + product_ext;

endmodule