`timescale 1ns/1ps

module bandpass_fir_mac #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter COEFF_W = 16,
    parameter ACC_W   = 64
) (
    input  [TAP_CNT*DATA_W-1:0]   samples_flat,
    input  [TAP_CNT*COEFF_W-1:0]  coeffs_flat,
    output signed [ACC_W-1:0]     acc_out
);

    localparam PROD_W = DATA_W + COEFF_W;

    integer i;

    reg signed [ACC_W-1:0]   acc_reg;
    reg signed [DATA_W-1:0]  sample_i;
    reg signed [COEFF_W-1:0] coeff_i;
    reg signed [PROD_W-1:0]  sample_ext;
    reg signed [PROD_W-1:0]  coeff_ext;
    reg signed [PROD_W-1:0]  product_i;
    reg signed [ACC_W-1:0]   product_acc;

    always @* begin
        acc_reg = {ACC_W{1'b0}};

        for (i = 0; i < TAP_CNT; i = i + 1) begin
            sample_i = samples_flat[i*DATA_W +: DATA_W];
            coeff_i  = coeffs_flat[i*COEFF_W +: COEFF_W];

            sample_ext = {{COEFF_W{sample_i[DATA_W-1]}}, sample_i};
            coeff_ext  = {{DATA_W{coeff_i[COEFF_W-1]}}, coeff_i};

            product_i   = sample_ext * coeff_ext;
            product_acc = product_i;

            acc_reg = acc_reg + product_acc;
        end
    end

    assign acc_out = acc_reg;

endmodule