`timescale 1ns/1ps

module aes_shiftrows (
    input  [127:0] state_in,
    output [127:0] state_out
);

    /*
     * AES state byte ordering is column-major:
     *
     *   b0  b4  b8   b12
     *   b1  b5  b9   b13
     *   b2  b6  b10  b14
     *   b3  b7  b11  b15
     *
     * where b0 = state_in[127:120].
     *
     * Encryption ShiftRows rotates rows left by 0, 1, 2, and 3 bytes:
     *
     *   b0  b4  b8   b12      b0  b4  b8   b12
     *   b1  b5  b9   b13  ->  b5  b9  b13  b1
     *   b2  b6  b10  b14      b10 b14 b2   b6
     *   b3  b7  b11  b15      b15 b3  b7   b11
     *
     * Re-flattened column-major, this becomes:
     *
     *   b0, b5, b10, b15,
     *   b4, b9, b14, b3,
     *   b8, b13, b2, b7,
     *   b12, b1, b6, b11
     */

    assign state_out = {
        state_in[127:120],  // b0
        state_in[87:80],    // b5
        state_in[47:40],    // b10
        state_in[7:0],      // b15

        state_in[95:88],    // b4
        state_in[55:48],    // b9
        state_in[15:8],     // b14
        state_in[103:96],   // b3

        state_in[63:56],    // b8
        state_in[23:16],    // b13
        state_in[111:104],  // b2
        state_in[71:64],    // b7

        state_in[31:24],    // b12
        state_in[119:112],  // b1
        state_in[79:72],    // b6
        state_in[39:32]     // b11
    };

endmodule