`timescale 1ns/1ps

module aes128_inv_mixcolumns (
    input  [127:0] state_in,
    output [127:0] state_out
);

    genvar c;

    /*
     * AES GF(2^8) multiply-by-x operation.
     * Reduction polynomial is x^8 + x^4 + x^3 + x + 1, encoded as 8'h1b.
     */
    function [7:0] xtime;
        input [7:0] x;
        begin
            xtime = {x[6:0], 1'b0} ^ ({8{x[7]}} & 8'h1b);
        end
    endfunction

    function [7:0] mul09;
        input [7:0] x;
        reg [7:0] x2;
        reg [7:0] x4;
        reg [7:0] x8;
        begin
            x2    = xtime(x);
            x4    = xtime(x2);
            x8    = xtime(x4);
            mul09 = x8 ^ x;
        end
    endfunction

    function [7:0] mul0b;
        input [7:0] x;
        reg [7:0] x2;
        reg [7:0] x4;
        reg [7:0] x8;
        begin
            x2    = xtime(x);
            x4    = xtime(x2);
            x8    = xtime(x4);
            mul0b = x8 ^ x2 ^ x;
        end
    endfunction

    function [7:0] mul0d;
        input [7:0] x;
        reg [7:0] x2;
        reg [7:0] x4;
        reg [7:0] x8;
        begin
            x2    = xtime(x);
            x4    = xtime(x2);
            x8    = xtime(x4);
            mul0d = x8 ^ x4 ^ x;
        end
    endfunction

    function [7:0] mul0e;
        input [7:0] x;
        reg [7:0] x2;
        reg [7:0] x4;
        reg [7:0] x8;
        begin
            x2    = xtime(x);
            x4    = xtime(x2);
            x8    = xtime(x4);
            mul0e = x8 ^ x4 ^ x2;
        end
    endfunction

    /*
     * The pipeline uses the standard AES byte ordering where each 32-bit
     * chunk is one AES column:
     *
     *   column 0: state_in[127:96]
     *   column 1: state_in[95:64]
     *   column 2: state_in[63:32]
     *   column 3: state_in[31:0]
     */
    generate
        for (c = 0; c < 4; c = c + 1) begin : GEN_INV_MIX_COL
            wire [7:0] a0;
            wire [7:0] a1;
            wire [7:0] a2;
            wire [7:0] a3;

            assign a0 = state_in[127 - 32*c -: 8];
            assign a1 = state_in[119 - 32*c -: 8];
            assign a2 = state_in[111 - 32*c -: 8];
            assign a3 = state_in[103 - 32*c -: 8];

            assign state_out[127 - 32*c -: 8] =
                mul0e(a0) ^ mul0b(a1) ^ mul0d(a2) ^ mul09(a3);

            assign state_out[119 - 32*c -: 8] =
                mul09(a0) ^ mul0e(a1) ^ mul0b(a2) ^ mul0d(a3);

            assign state_out[111 - 32*c -: 8] =
                mul0d(a0) ^ mul09(a1) ^ mul0e(a2) ^ mul0b(a3);

            assign state_out[103 - 32*c -: 8] =
                mul0b(a0) ^ mul0d(a1) ^ mul09(a2) ^ mul0e(a3);
        end
    endgenerate

endmodule