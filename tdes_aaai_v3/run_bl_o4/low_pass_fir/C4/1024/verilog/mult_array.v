module mult_array #(
    parameter DATA_W  = 20,
    parameter COEFF_W = 16,
    parameter TAP_CNT = 101
) (
    input  wire signed [DATA_W*TAP_CNT-1:0]   taps,
    input  wire signed [COEFF_W*TAP_CNT-1:0]  coeffs,
    output wire signed [(DATA_W+COEFF_W)*TAP_CNT-1:0] prods
);
    // Width of each product
    localparam PROD_W = DATA_W + COEFF_W;

    genvar i;
    generate
        for (i = 0; i < TAP_CNT; i = i + 1) begin : mul
            // extract each tap and coefficient
            wire signed [DATA_W-1:0]    tap_i   = taps[(i+1)*DATA_W-1   : i*DATA_W];
            wire signed [COEFF_W-1:0]   coeff_i = coeffs[(i+1)*COEFF_W-1 : i*COEFF_W];
            // perform multiplication
            wire signed [PROD_W-1:0]    prod_i;
            assign prod_i = tap_i * coeff_i;
            // pack into output vector
            assign prods[(i+1)*PROD_W-1 : i*PROD_W] = prod_i;
        end
    endgenerate
endmodule