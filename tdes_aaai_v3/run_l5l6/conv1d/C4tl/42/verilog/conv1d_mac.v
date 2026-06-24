`timescale 1ns/1ps

module conv1d_mac #(
    parameter DATA_W      = 8,
    parameter KERNEL_SIZE = 5,
    parameter COEFF_W     = 12,
    parameter ACC_W       = 28
) (
    input  [KERNEL_SIZE*DATA_W-1:0]   window_flat,
    input  [KERNEL_SIZE*COEFF_W-1:0]  coeffs_flat,
    output reg signed [ACC_W-1:0]     acc_out
);

    /*
     * Samples are treated as unsigned input data and are given one leading
     * zero bit before the signed multiply.  Coefficients are signed.
     */
    localparam SAMPLE_SW = DATA_W + 1;
    localparam PROD_W    = SAMPLE_SW + COEFF_W;

    integer i;
    integer sample_index;

    reg signed [SAMPLE_SW-1:0] sample_s;
    reg signed [COEFF_W-1:0]   coeff_s;
    reg signed [PROD_W-1:0]    product_s;

    /*
     * Resize a signed product to ACC_W bits.
     *
     * This handles both:
     *   - ACC_W >= PROD_W : sign-extension
     *   - ACC_W <  PROD_W : two's-complement truncation
     *
     * Avoids constructs such as {(ACC_W-PROD_W){...}}, which are illegal
     * when ACC_W is smaller than PROD_W.
     */
    function signed [ACC_W-1:0] resize_signed_to_acc;
        input signed [PROD_W-1:0] value;
        integer b;
        begin
            for (b = 0; b < ACC_W; b = b + 1) begin
                if (b < PROD_W)
                    resize_signed_to_acc[b] = value[b];
                else
                    resize_signed_to_acc[b] = value[PROD_W-1];
            end
        end
    endfunction

    always @* begin
        acc_out = {ACC_W{1'b0}};

        for (i = 0; i < KERNEL_SIZE; i = i + 1) begin
            /*
             * Coefficients are stored in natural kernel order.
             * The window is consumed in reverse tap order so coeff[0] is
             * applied to the oldest/leftmost sample in the convolution window.
             */
            sample_index = KERNEL_SIZE - 1 - i;

            sample_s  = {1'b0, window_flat[sample_index*DATA_W +: DATA_W]};
            coeff_s   = coeffs_flat[i*COEFF_W +: COEFF_W];
            product_s = sample_s * coeff_s;

            acc_out = acc_out + resize_signed_to_acc(product_s);
        end
    end

endmodule