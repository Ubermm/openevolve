`timescale 1ns/1ps

module highpass_fir_delay_next #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101
) (
    input                            valid_in,
    input      [DATA_W-1:0]          data_in,
    input      [DATA_W*TAP_CNT-1:0]  delay_line_in,
    output reg [DATA_W*TAP_CNT-1:0]  delay_line_out
);

    integer tap_idx;

    function [DATA_W-1:0] clean_sample;
        input [DATA_W-1:0] sample;
        begin
            clean_sample = sample;
            // synthesis translate_off
            if ((^sample) === 1'bx)
                clean_sample = {DATA_W{1'b0}};
            // synthesis translate_on
        end
    endfunction

    always @* begin
        for (tap_idx = 0; tap_idx < TAP_CNT; tap_idx = tap_idx + 1) begin
            delay_line_out[tap_idx*DATA_W +: DATA_W] =
                clean_sample(delay_line_in[tap_idx*DATA_W +: DATA_W]);
        end

        if (valid_in) begin
            delay_line_out[0 +: DATA_W] = clean_sample(data_in);

            for (tap_idx = 1; tap_idx < TAP_CNT; tap_idx = tap_idx + 1) begin
                delay_line_out[tap_idx*DATA_W +: DATA_W] =
                    clean_sample(delay_line_in[(tap_idx-1)*DATA_W +: DATA_W]);
            end
        end
    end

endmodule