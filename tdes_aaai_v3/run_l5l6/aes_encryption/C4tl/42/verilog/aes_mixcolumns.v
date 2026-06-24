`timescale 1ns/1ps

module aes_mixcolumns (
    input  [127:0] state_in,
    output [127:0] state_out
);

    /*
     * AES GF(2^8) multiply-by-2.
     * If the input MSB is set, the shifted value is reduced by
     * the AES irreducible polynomial x^8 + x^4 + x^3 + x + 1,
     * represented by 8'h1b after the left shift.
     */
    function [7:0] xtime;
        input [7:0] x;
        begin
            xtime = {x[6:0], 1'b0} ^ ({8{x[7]}} & 8'h1b);
        end
    endfunction

    function [7:0] mul2;
        input [7:0] x;
        begin
            mul2 = xtime(x);
        end
    endfunction

    function [7:0] mul3;
        input [7:0] x;
        begin
            mul3 = xtime(x) ^ x;
        end
    endfunction

    /*
     * Mix one AES state column.
     *
     * The design uses column-major AES state ordering. Therefore each
     * contiguous 32-bit slice of the 128-bit state is one AES column.
     * Within a column, the byte order is:
     *
     *   col[31:24] = a0
     *   col[23:16] = a1
     *   col[15:8]  = a2
     *   col[7:0]   = a3
     */
    function [31:0] mix_column;
        input [31:0] col;

        reg [7:0] a0;
        reg [7:0] a1;
        reg [7:0] a2;
        reg [7:0] a3;

        reg [7:0] r0;
        reg [7:0] r1;
        reg [7:0] r2;
        reg [7:0] r3;

        begin
            a0 = col[31:24];
            a1 = col[23:16];
            a2 = col[15:8];
            a3 = col[7:0];

            r0 = mul2(a0) ^ mul3(a1) ^ a2       ^ a3;
            r1 = a0       ^ mul2(a1) ^ mul3(a2) ^ a3;
            r2 = a0       ^ a1       ^ mul2(a2) ^ mul3(a3);
            r3 = mul3(a0) ^ a1       ^ a2       ^ mul2(a3);

            mix_column = {r0, r1, r2, r3};
        end
    endfunction

    assign state_out[127:96] = mix_column(state_in[127:96]);
    assign state_out[95:64]  = mix_column(state_in[95:64]);
    assign state_out[63:32]  = mix_column(state_in[63:32]);
    assign state_out[31:0]   = mix_column(state_in[31:0]);

endmodule