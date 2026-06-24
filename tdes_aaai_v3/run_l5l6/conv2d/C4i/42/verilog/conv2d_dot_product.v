`timescale 1ns/1ps

module conv2d_dot_product #(
    parameter DATA_W      = 8,
    parameter KERNEL_SIZE = 3,
    parameter COEFF_W     = 16,
    parameter ACC_W       = 32
) (
    input      [KERNEL_SIZE*KERNEL_SIZE*DATA_W-1:0]   window_flat,
    input      [KERNEL_SIZE*KERNEL_SIZE*COEFF_W-1:0]  coeffs_flat,
    output reg signed [ACC_W-1:0]                     accum
);

    localparam integer TAPS      = KERNEL_SIZE * KERNEL_SIZE;
    localparam integer PRODUCT_W = DATA_W + COEFF_W + 1;

    integer i;

    reg        [DATA_W-1:0]       pix;
    reg signed [COEFF_W-1:0]      coeff;

    reg signed [PRODUCT_W-1:0]    pix_ext;
    reg signed [PRODUCT_W-1:0]    coeff_ext;
    reg signed [PRODUCT_W-1:0]    product_full;
    reg signed [ACC_W-1:0]        product_acc;

    always @* begin
        accum = {ACC_W{1'b0}};

        for (i = 0; i < TAPS; i = i + 1) begin
            pix   = window_flat[i*DATA_W +: DATA_W];
            coeff = coeffs_flat[i*COEFF_W +: COEFF_W];

            /*
             * Pixels are unsigned image samples.  Add an explicit leading
             * zero before sign extension so that the pixel is always treated
             * as non-negative.
             */
            pix_ext = {{(PRODUCT_W-(DATA_W+1)){1'b0}}, 1'b0, pix};

            /*
             * Coefficients are signed and must be sign-extended before the
             * multiply.
             */
            coeff_ext = {{(PRODUCT_W-COEFF_W){coeff[COEFF_W-1]}}, coeff};

            /*
             * PRODUCT_W is large enough for DATA_W-bit unsigned pixel times
             * COEFF_W-bit signed coefficient.
             */
            product_full = pix_ext * coeff_ext;

            /*
             * Assignment to the signed ACC_W temporary sign-extends or
             * truncates according to ACC_W.  The intended design parameters
             * provide sufficient accumulator width.
             */
            product_acc = product_full;

            accum = accum + product_acc;
        end
    end

endmodule