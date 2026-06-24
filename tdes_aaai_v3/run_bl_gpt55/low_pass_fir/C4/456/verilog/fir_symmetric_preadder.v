`timescale 1ns/1ps

module fir_symmetric_preadder #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101
) (
    input  [TAP_CNT*DATA_W-1:0]             sample_flat,
    output [((TAP_CNT-1)/2)*(DATA_W+1)-1:0] pair_sums_flat,
    output [DATA_W-1:0]                     center_sample
);

    localparam PAIR_CNT   = (TAP_CNT - 1) / 2;
    localparam CENTER_IDX = (TAP_CNT - 1) / 2;

    genvar i;
    generate
        for (i = 0; i < PAIR_CNT; i = i + 1) begin : gen_pair_sums
            wire signed [DATA_W-1:0] sample_a;
            wire signed [DATA_W-1:0] sample_b;
            wire signed [DATA_W:0]   sample_a_ext;
            wire signed [DATA_W:0]   sample_b_ext;
            wire signed [DATA_W:0]   pair_sum;

            assign sample_a = sample_flat[i*DATA_W +: DATA_W];
            assign sample_b = sample_flat[(TAP_CNT-1-i)*DATA_W +: DATA_W];

            assign sample_a_ext = {sample_a[DATA_W-1], sample_a};
            assign sample_b_ext = {sample_b[DATA_W-1], sample_b};
            assign pair_sum     = sample_a_ext + sample_b_ext;

            assign pair_sums_flat[i*(DATA_W+1) +: (DATA_W+1)] = pair_sum;
        end
    endgenerate

    assign center_sample = sample_flat[CENTER_IDX*DATA_W +: DATA_W];

endmodule