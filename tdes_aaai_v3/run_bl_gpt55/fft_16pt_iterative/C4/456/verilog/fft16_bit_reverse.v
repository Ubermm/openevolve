`timescale 1ns/1ps

module fft16_bit_reverse #(
    parameter ADDR_W = 4
) (
    input  [ADDR_W-1:0] addr_in,
    output [ADDR_W-1:0] addr_out
);

    genvar i;
    generate
        for (i = 0; i < ADDR_W; i = i + 1) begin : gen_bit_reverse
            assign addr_out[i] = addr_in[ADDR_W-1-i];
        end
    endgenerate

endmodule