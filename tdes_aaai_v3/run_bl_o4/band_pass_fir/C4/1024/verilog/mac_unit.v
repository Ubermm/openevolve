module mac_unit #(
  parameter DATA_W  = 20,
  parameter COEFF_W = 16,
  parameter ACC_W   = 64
)(
  input  wire signed [ACC_W-1:0]    acc_in,
  input  wire signed [DATA_W-1:0]   sample,
  input  wire signed [COEFF_W-1:0]  coeff,
  output wire signed [ACC_W-1:0]    acc_out
);

  // Product width
  localparam PROD_W = DATA_W + COEFF_W;

  // Multiply signed sample by signed coefficient
  wire signed [PROD_W-1:0] product;
  assign product = sample * coeff;

  // Sign-extend the product to ACC_W bits
  wire signed [ACC_W-1:0] product_ext;
  assign product_ext = {{(ACC_W-PROD_W){product[PROD_W-1]}}, product};

  // Accumulate
  assign acc_out = acc_in + product_ext;

endmodule