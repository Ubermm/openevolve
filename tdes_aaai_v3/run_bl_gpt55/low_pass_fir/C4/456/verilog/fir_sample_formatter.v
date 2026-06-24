`timescale 1ns/1ps

module fir_sample_formatter #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101
) (
    input  [DATA_W-1:0]                 data_in,
    input  [(TAP_CNT-1)*DATA_W-1:0]     delay_flat,
    output [TAP_CNT*DATA_W-1:0]         sample_flat
);

    /*
     * Pure-combinational sample formatter.
     *
     * LSB-first tap packing:
     *   tap 0             = x[n]                 = data_in
     *   tap 1             = x[n-1]               = delay_flat tap 0
     *   ...
     *   tap TAP_CNT-1     = x[n-(TAP_CNT-1)]     = delay_flat tap TAP_CNT-2
     *
     * Each tap occupies DATA_W bits:
     *   sample_flat[k*DATA_W +: DATA_W]
     */

    assign sample_flat[0 +: DATA_W] = data_in;

    genvar tap;
    generate
        for (tap = 1; tap < TAP_CNT; tap = tap + 1) begin : gen_sample_pack
            assign sample_flat[tap*DATA_W +: DATA_W] =
                   delay_flat[(tap-1)*DATA_W +: DATA_W];
        end
    endgenerate

endmodule