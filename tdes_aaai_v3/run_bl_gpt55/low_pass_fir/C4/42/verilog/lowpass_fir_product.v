module lowpass_fir_product #(
    parameter SAMPLE_W  = 21,
    parameter COEFF_W   = 16,
    parameter PRODUCT_W = SAMPLE_W + COEFF_W
) (
    input  signed [SAMPLE_W-1:0]  sample_sum,
    input  signed [COEFF_W-1:0]   coeff,
    output signed [PRODUCT_W-1:0] product
);

    localparam FULL_PRODUCT_W = SAMPLE_W + COEFF_W;

    wire signed [FULL_PRODUCT_W-1:0] sample_ext;
    wire signed [FULL_PRODUCT_W-1:0] coeff_ext;
    wire signed [FULL_PRODUCT_W-1:0] product_full;

    assign sample_ext   = {{COEFF_W{sample_sum[SAMPLE_W-1]}}, sample_sum};
    assign coeff_ext    = {{SAMPLE_W{coeff[COEFF_W-1]}}, coeff};
    assign product_full = sample_ext * coeff_ext;

    generate
        if (PRODUCT_W == FULL_PRODUCT_W) begin : gen_product_exact
            assign product = product_full;
        end else if (PRODUCT_W > FULL_PRODUCT_W) begin : gen_product_extend
            assign product = {{(PRODUCT_W-FULL_PRODUCT_W){product_full[FULL_PRODUCT_W-1]}}, product_full};
        end else begin : gen_product_truncate
            assign product = product_full[PRODUCT_W-1:0];
        end
    endgenerate

endmodule