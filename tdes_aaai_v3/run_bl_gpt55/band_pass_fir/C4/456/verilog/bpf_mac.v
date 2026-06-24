module bpf_mac #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter COEFF_W = 16,
    parameter ACC_W   = 64
) (
    input  [TAP_CNT*DATA_W-1:0]   samples_flat,
    input  [TAP_CNT*COEFF_W-1:0]  coeff_flat,
    output reg signed [ACC_W-1:0] acc_out
);

    localparam PROD_W = DATA_W + COEFF_W;

    integer i;

    reg signed [DATA_W-1:0]  sample_s;
    reg signed [COEFF_W-1:0] coeff_s;
    reg signed [PROD_W-1:0]  product_s;
    reg signed [ACC_W-1:0]   product_ext;

    always @* begin
        acc_out = {ACC_W{1'b0}};

        for (i = 0; i < TAP_CNT; i = i + 1) begin
            sample_s  = samples_flat[i*DATA_W +: DATA_W];
            coeff_s   = coeff_flat[i*COEFF_W +: COEFF_W];
            product_s = sample_s * coeff_s;

            product_ext = {{(ACC_W-PROD_W){product_s[PROD_W-1]}}, product_s};
            acc_out = acc_out + product_ext;
        end
    end

endmodule