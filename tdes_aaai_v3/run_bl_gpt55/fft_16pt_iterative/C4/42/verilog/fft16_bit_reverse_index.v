module fft16_bit_reverse_index (
    input  [3:0] idx,
    output [3:0] rev
);
    assign rev = {idx[0], idx[1], idx[2], idx[3]};
endmodule