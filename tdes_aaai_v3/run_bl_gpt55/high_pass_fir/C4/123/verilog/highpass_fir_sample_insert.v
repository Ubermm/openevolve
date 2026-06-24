`timescale 1ns/1ps

module highpass_fir_sample_insert #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101
) (
    input  [DATA_W*TAP_CNT-1:0] samples_flat,
    input  [DATA_W-1:0]         data_in,
    input                       valid_in,
    output [DATA_W*TAP_CNT-1:0] next_samples_flat
);

genvar i;

generate
    if (TAP_CNT == 1) begin : gen_single_tap
        assign next_samples_flat[DATA_W-1:0] =
            valid_in ? data_in : samples_flat[DATA_W-1:0];
    end else begin : gen_multi_tap
        assign next_samples_flat[DATA_W-1:0] =
            valid_in ? data_in : samples_flat[DATA_W-1:0];

        for (i = 1; i < TAP_CNT; i = i + 1) begin : gen_shift_taps
            assign next_samples_flat[i*DATA_W +: DATA_W] =
                valid_in ? samples_flat[(i-1)*DATA_W +: DATA_W]
                         : samples_flat[i*DATA_W +: DATA_W];
        end
    end
endgenerate

endmodule