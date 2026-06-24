`timescale 1ns/1ps

module hp_sample_coeff_product #(
    parameter DATA_W  = 20,
    parameter COEFF_W = 16,
    parameter PROD_W  = 64
) (
    input  signed [DATA_W-1:0]   sample,
    input  signed [COEFF_W-1:0]  coeff,
    output signed [PROD_W-1:0]   product
);

    localparam RAW_PROD_W = DATA_W + COEFF_W;

    wire signed [RAW_PROD_W-1:0] sample_ext;
    wire signed [RAW_PROD_W-1:0] coeff_ext;
    wire signed [RAW_PROD_W-1:0] raw_product;

    assign sample_ext  = {{COEFF_W{sample[DATA_W-1]}}, sample};
    assign coeff_ext   = {{DATA_W{coeff[COEFF_W-1]}}, coeff};

    assign raw_product = sample_ext * coeff_ext;

    generate
        if (PROD_W > RAW_PROD_W) begin : gen_product_sign_extend
            assign product = {{(PROD_W-RAW_PROD_W){raw_product[RAW_PROD_W-1]}}, raw_product};
        end else if (PROD_W == RAW_PROD_W) begin : gen_product_exact
            assign product = raw_product;
        end else begin : gen_product_truncate
            assign product = raw_product[PROD_W-1:0];
        end
    endgenerate

endmodule