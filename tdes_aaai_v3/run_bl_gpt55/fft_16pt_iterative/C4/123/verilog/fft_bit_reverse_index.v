`timescale 1ns/1ps

module fft_bit_reverse_index #(
    parameter LOGN = 4
) (
    input  [LOGN-1:0] idx_in,
    output [LOGN-1:0] idx_out
);

    genvar i;
    generate
        for (i = 0; i < LOGN; i = i + 1) begin : gen_bit_reverse
            assign idx_out[i] = idx_in[LOGN-1-i];
        end
    endgenerate

endmodule