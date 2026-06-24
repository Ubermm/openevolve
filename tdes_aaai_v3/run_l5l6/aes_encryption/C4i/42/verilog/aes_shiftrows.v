`timescale 1ns/1ps

module aes_shiftrows (
    input  [127:0] state_in,
    output [127:0] state_out
);

    /*
        AES state byte ordering is column-major:

            column 0   column 1   column 2   column 3
        row 0   b0        b4        b8        b12
        row 1   b1        b5        b9        b13
        row 2   b2        b6        b10       b14
        row 3   b3        b7        b11       b15

        where:
            b0  = state_in[127:120]
            b1  = state_in[119:112]
            ...
            b15 = state_in[7:0]

        Forward AES ShiftRows:
            row 0: unchanged
            row 1: rotate left by 1
            row 2: rotate left by 2
            row 3: rotate left by 3
    */

    // Column 0 after ShiftRows: b0, b5, b10, b15
    assign state_out[127:120] = state_in[127:120];
    assign state_out[119:112] = state_in[ 87: 80];
    assign state_out[111:104] = state_in[ 47: 40];
    assign state_out[103: 96] = state_in[  7:  0];

    // Column 1 after ShiftRows: b4, b9, b14, b3
    assign state_out[ 95: 88] = state_in[ 95: 88];
    assign state_out[ 87: 80] = state_in[ 55: 48];
    assign state_out[ 79: 72] = state_in[ 15:  8];
    assign state_out[ 71: 64] = state_in[103: 96];

    // Column 2 after ShiftRows: b8, b13, b2, b7
    assign state_out[ 63: 56] = state_in[ 63: 56];
    assign state_out[ 55: 48] = state_in[ 23: 16];
    assign state_out[ 47: 40] = state_in[111:104];
    assign state_out[ 39: 32] = state_in[ 71: 64];

    // Column 3 after ShiftRows: b12, b1, b6, b11
    assign state_out[ 31: 24] = state_in[ 31: 24];
    assign state_out[ 23: 16] = state_in[119:112];
    assign state_out[ 15:  8] = state_in[ 79: 72];
    assign state_out[  7:  0] = state_in[ 39: 32];

endmodule