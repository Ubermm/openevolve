`timescale 1ns/1ps

module conv2d_dot_product #(
    parameter DATA_W      = 8,
    parameter COEFF_W     = 16,
    parameter KERNEL_SIZE = 3,
    parameter ACC_W       = 32
) (
    input  [DATA_W*KERNEL_SIZE*KERNEL_SIZE-1:0]  pixels,
    input  [COEFF_W*KERNEL_SIZE*KERNEL_SIZE-1:0] coeffs,
    output reg signed [ACC_W-1:0]                sum
);

    localparam K2     = KERNEL_SIZE * KERNEL_SIZE;
    localparam PROD_W = DATA_W + COEFF_W + 1;

    integer i;

    reg signed [PROD_W-1:0] pix_mul;
    reg signed [PROD_W-1:0] coeff_mul;
    reg signed [PROD_W-1:0] prod;

    always @* begin
        sum = {ACC_W{1'b0}};

        for (i = 0; i < K2; i = i + 1) begin
            /*
             * Pixels are unsigned samples.  Add an explicit leading zero and
             * extend to the internal signed product width.
             */
            pix_mul = {
                {COEFF_W{1'b0}},
                1'b0,
                pixels[i*DATA_W +: DATA_W]
            };

            /*
             * Coefficients are signed two's-complement values.  Sign-extend
             * them to the internal product width before multiplication.
             */
            coeff_mul = {
                {(DATA_W+1){coeffs[i*COEFF_W + COEFF_W - 1]}},
                coeffs[i*COEFF_W +: COEFF_W]
            };

            prod = pix_mul * coeff_mul;

            /*
             * Let Verilog's signed assignment/addition rules resize the
             * product to the accumulator width.  This avoids illegal negative
             * replication counts when ACC_W is smaller than PROD_W.
             */
            sum = sum + prod;
        end
    end

endmodule