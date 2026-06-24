module bpf_sample_shift #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101
) (
    input  signed [DATA_W-1:0]         sample_in,
    input         [TAP_CNT*DATA_W-1:0] samples_curr_flat,
    output        [TAP_CNT*DATA_W-1:0] samples_next_flat
);

    genvar tap_idx;

    generate
        for (tap_idx = 0; tap_idx < TAP_CNT; tap_idx = tap_idx + 1) begin : gen_sample_shift
            if (tap_idx == 0) begin : gen_insert_new_sample
                assign samples_next_flat[tap_idx*DATA_W +: DATA_W] = sample_in;
            end else begin : gen_shift_previous_samples
                assign samples_next_flat[tap_idx*DATA_W +: DATA_W] =
                    samples_curr_flat[(tap_idx-1)*DATA_W +: DATA_W];
            end
        end
    endgenerate

endmodule