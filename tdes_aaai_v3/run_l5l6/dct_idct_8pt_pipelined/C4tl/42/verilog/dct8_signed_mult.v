`timescale 1ns/1ps

module dct8_signed_mult #(
    parameter DATA_W  = 12,
    parameter COEFF_W = 16
) (
    input  signed [DATA_W-1:0]              sample,
    input  signed [COEFF_W-1:0]             coeff,
    output signed [DATA_W+COEFF_W-1:0]      product
);

    localparam PRODUCT_W = DATA_W + COEFF_W;

    wire signed [PRODUCT_W-1:0] sample_ext;
    wire signed [PRODUCT_W-1:0] coeff_ext;

    assign sample_ext = {{COEFF_W{sample[DATA_W-1]}}, sample};
    assign coeff_ext  = {{DATA_W{coeff[COEFF_W-1]}}, coeff};

    assign product = sample_ext * coeff_ext;

endmodule