`timescale 1ns/1ps

module bpf_tap_product #(
    parameter DATA_W  = 20,
    parameter COEFF_W = 16,
    parameter PROD_W  = 64
) (
    input  signed [DATA_W-1:0]  sample,
    input  signed [COEFF_W-1:0] coeff,
    output signed [PROD_W-1:0]  product
);

    wire signed [PROD_W-1:0] sample_ext;
    wire signed [PROD_W-1:0] coeff_ext;

    assign sample_ext = {{(PROD_W-DATA_W){sample[DATA_W-1]}}, sample};
    assign coeff_ext  = {{(PROD_W-COEFF_W){coeff[COEFF_W-1]}}, coeff};

    assign product = sample_ext * coeff_ext;

endmodule