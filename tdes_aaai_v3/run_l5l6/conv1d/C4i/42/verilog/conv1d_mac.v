`timescale 1ns/1ps

module conv1d_mac #(
    parameter DATA_W      = 8,
    parameter KERNEL_SIZE = 5,
    parameter COEFF_W     = 16,
    parameter ACC_W       = 32
) (
    input  [DATA_W*KERNEL_SIZE-1:0]   window_flat,
    input  [COEFF_W*KERNEL_SIZE-1:0]  coeffs_flat,
    output reg signed [ACC_W-1:0]     acc_out
);

    integer i;

    reg signed [DATA_W:0]   sample_s;
    reg signed [COEFF_W-1:0] coeff_s;
    reg signed [ACC_W-1:0]  product_s;
    reg signed [ACC_W-1:0]  accum_s;

    always @* begin
        accum_s = {ACC_W{1'b0}};

        for (i = 0; i < KERNEL_SIZE; i = i + 1) begin
            /*
             * Samples are input data values, so interpret them as non-negative
             * magnitudes by prepending a zero sign bit before casting signed.
             *
             * Coefficients are signed two's-complement values.
             */
            sample_s  = $signed({1'b0, window_flat[i*DATA_W +: DATA_W]});
            coeff_s   = $signed(coeffs_flat[i*COEFF_W +: COEFF_W]);

            product_s = sample_s * coeff_s;
            accum_s   = accum_s + product_s;
        end

        acc_out = accum_s;
    end

endmodule