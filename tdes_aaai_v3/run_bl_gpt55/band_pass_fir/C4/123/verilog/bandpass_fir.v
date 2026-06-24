`timescale 1ns/1ps

module bandpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4
) (
    input                          clk,
    input                          rst,
    input                          valid_in,
    input      [DATA_W-1:0]        data_in,
    output                         valid_out,
    output     [DATA_W+GAIN_W-1:0] data_out
);

    localparam COEFF_W = 16;
    localparam PROD_W  = 64;
    localparam OUT_W   = DATA_W + GAIN_W;

    reg signed [DATA_W-1:0] sample_delay [0:TAP_CNT-2];

    reg                    valid_out_r;
    reg signed [OUT_W-1:0] data_out_r;

    wire signed [DATA_W-1:0] data_in_s;
    assign data_in_s = data_in;

    wire signed [DATA_W-1:0] tap_sample [0:TAP_CNT-1];
    wire signed [COEFF_W-1:0] coeff     [0:TAP_CNT-1];
    wire signed [PROD_W-1:0]  product   [0:TAP_CNT-1];

    wire [TAP_CNT*PROD_W-1:0] products_flat;
    wire signed [PROD_W-1:0]  acc_comb;
    wire signed [OUT_W-1:0]   quantized_comb;

    assign tap_sample[0] = data_in_s;

    genvar gi;
    generate
        for (gi = 1; gi < TAP_CNT; gi = gi + 1) begin : g_sample_taps
            assign tap_sample[gi] = sample_delay[gi-1];
        end

        for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : g_taps
            bpf_coeff_const #(
                .INDEX(gi),
                .COEFF_W(COEFF_W)
            ) u_coeff_const (
                .coeff(coeff[gi])
            );

            bpf_tap_product #(
                .DATA_W(DATA_W),
                .COEFF_W(COEFF_W),
                .PROD_W(PROD_W)
            ) u_tap_product (
                .sample(tap_sample[gi]),
                .coeff(coeff[gi]),
                .product(product[gi])
            );

            assign products_flat[gi*PROD_W +: PROD_W] = product[gi];
        end
    endgenerate

    bpf_adder_tree_sum #(
        .TAP_CNT(TAP_CNT),
        .PROD_W(PROD_W)
    ) u_adder_tree_sum (
        .products_flat(products_flat),
        .sum(acc_comb)
    );

    bpf_output_quantizer #(
        .ACC_W(PROD_W),
        .OUT_W(OUT_W),
        .SHIFT(15)
    ) u_output_quantizer (
        .acc(acc_comb),
        .data_out(quantized_comb)
    );

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            valid_out_r <= 1'b0;
            data_out_r  <= {OUT_W{1'b0}};
            for (i = 0; i < TAP_CNT-1; i = i + 1) begin
                sample_delay[i] <= {DATA_W{1'b0}};
            end
        end else begin
            valid_out_r <= valid_in;

            if (valid_in) begin
                data_out_r <= quantized_comb;

                sample_delay[0] <= data_in_s;
                for (i = 1; i < TAP_CNT-1; i = i + 1) begin
                    sample_delay[i] <= sample_delay[i-1];
                end
            end
        end
    end

    assign valid_out = valid_out_r;
    assign data_out  = data_out_r;

endmodule