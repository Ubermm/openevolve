`timescale 1ns/1ps

module aes128_inv_shiftrows (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    // AES column-major byte ordering:
    //
    // state_in = {
    //   s00, s10, s20, s30,
    //   s01, s11, s21, s31,
    //   s02, s12, s22, s32,
    //   s03, s13, s23, s33
    // }
    //
    // where sij is row i, column j.

    wire [7:0] b0  = state_in[127:120];
    wire [7:0] b1  = state_in[119:112];
    wire [7:0] b2  = state_in[111:104];
    wire [7:0] b3  = state_in[103:96];

    wire [7:0] b4  = state_in[95:88];
    wire [7:0] b5  = state_in[87:80];
    wire [7:0] b6  = state_in[79:72];
    wire [7:0] b7  = state_in[71:64];

    wire [7:0] b8  = state_in[63:56];
    wire [7:0] b9  = state_in[55:48];
    wire [7:0] b10 = state_in[47:40];
    wire [7:0] b11 = state_in[39:32];

    wire [7:0] b12 = state_in[31:24];
    wire [7:0] b13 = state_in[23:16];
    wire [7:0] b14 = state_in[15:8];
    wire [7:0] b15 = state_in[7:0];

    // Inverse ShiftRows:
    // row 0 unchanged
    // row 1 rotates right by 1
    // row 2 rotates right by 2
    // row 3 rotates right by 3
    assign state_out = {
        b0,  b13, b10, b7,
        b4,  b1,  b14, b11,
        b8,  b5,  b2,  b15,
        b12, b9,  b6,  b3
    };

endmodule