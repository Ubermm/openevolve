`timescale 1ns/1ps

module aes_mixcolumns (
    input  [127:0] state_in,
    output [127:0] state_out
);

    /*
     * AES GF(2^8) multiply by x, also called xtime().
     *
     * If the input MSB is clear, multiplication by 2 is just a left shift.
     * If the input MSB is set, the shifted value must be reduced modulo
     * the AES irreducible polynomial, which corresponds to XOR with 8'h1b.
     */
    function [7:0] xtime;
        input [7:0] b;
        begin
            xtime = {b[6:0], 1'b0} ^ (8'h1b & {8{b[7]}});
        end
    endfunction

    function [7:0] mul2;
        input [7:0] b;
        begin
            mul2 = xtime(b);
        end
    endfunction

    function [7:0] mul3;
        input [7:0] b;
        begin
            mul3 = xtime(b) ^ b;
        end
    endfunction

    /*
     * Mix one AES column.
     *
     * Byte ordering follows the column-major AES state convention used by
     * the surrounding pipeline:
     *
     *   c[31:24] = s0
     *   c[23:16] = s1
     *   c[15:8]  = s2
     *   c[7:0]   = s3
     */
    function [31:0] mix_col;
        input [31:0] c;

        reg [7:0] s0;
        reg [7:0] s1;
        reg [7:0] s2;
        reg [7:0] s3;

        reg [7:0] m0;
        reg [7:0] m1;
        reg [7:0] m2;
        reg [7:0] m3;

        begin
            s0 = c[31:24];
            s1 = c[23:16];
            s2 = c[15:8];
            s3 = c[7:0];

            m0 = mul2(s0) ^ mul3(s1) ^ s2       ^ s3;
            m1 = s0       ^ mul2(s1) ^ mul3(s2) ^ s3;
            m2 = s0       ^ s1       ^ mul2(s2) ^ mul3(s3);
            m3 = mul3(s0) ^ s1       ^ s2       ^ mul2(s3);

            mix_col = {m0, m1, m2, m3};
        end
    endfunction

    assign state_out[127:96] = mix_col(state_in[127:96]);
    assign state_out[ 95:64] = mix_col(state_in[ 95:64]);
    assign state_out[ 63:32] = mix_col(state_in[ 63:32]);
    assign state_out[ 31: 0] = mix_col(state_in[ 31: 0]);

endmodule