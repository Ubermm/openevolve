`timescale 1ns/1ps

module aes128_key_expand (
    input      [127:0]  key_in,
    output reg [1407:0] round_keys
);

    reg [31:0] w [0:43];
    integer i;

    function [7:0] gf_mul;
        input [7:0] a;
        input [7:0] b;
        reg   [7:0] aa;
        reg   [7:0] bb;
        reg   [7:0] p;
        integer j;
        begin
            aa = a;
            bb = b;
            p  = 8'h00;

            for (j = 0; j < 8; j = j + 1) begin
                if (bb[0])
                    p = p ^ aa;

                aa = aa[7] ? ((aa << 1) ^ 8'h1b) : (aa << 1);
                bb = bb >> 1;
            end

            gf_mul = p;
        end
    endfunction

    function [7:0] gf_inv;
        input [7:0] x;
        reg   [7:0] result;
        reg   [7:0] base;
        reg   [7:0] exp;
        integer j;
        begin
            if (x == 8'h00) begin
                gf_inv = 8'h00;
            end else begin
                result = 8'h01;
                base   = x;
                exp    = 8'hfe;   // x^-1 = x^254 in GF(2^8)

                for (j = 0; j < 8; j = j + 1) begin
                    if (exp[0])
                        result = gf_mul(result, base);

                    base = gf_mul(base, base);
                    exp  = exp >> 1;
                end

                gf_inv = result;
            end
        end
    endfunction

    function [7:0] aes_sbox;
        input [7:0] x;
        reg   [7:0] a;
        reg   [7:0] y;
        begin
            a = gf_inv(x);

            // AES affine transform with constant 8'h63.
            y[0] = a[0] ^ a[4] ^ a[5] ^ a[6] ^ a[7] ^ 1'b1;
            y[1] = a[1] ^ a[5] ^ a[6] ^ a[7] ^ a[0] ^ 1'b1;
            y[2] = a[2] ^ a[6] ^ a[7] ^ a[0] ^ a[1] ^ 1'b0;
            y[3] = a[3] ^ a[7] ^ a[0] ^ a[1] ^ a[2] ^ 1'b0;
            y[4] = a[4] ^ a[0] ^ a[1] ^ a[2] ^ a[3] ^ 1'b0;
            y[5] = a[5] ^ a[1] ^ a[2] ^ a[3] ^ a[4] ^ 1'b1;
            y[6] = a[6] ^ a[2] ^ a[3] ^ a[4] ^ a[5] ^ 1'b1;
            y[7] = a[7] ^ a[3] ^ a[4] ^ a[5] ^ a[6] ^ 1'b0;

            aes_sbox = y;
        end
    endfunction

    function [31:0] subword;
        input [31:0] x;
        begin
            subword = {
                aes_sbox(x[31:24]),
                aes_sbox(x[23:16]),
                aes_sbox(x[15:8]),
                aes_sbox(x[7:0])
            };
        end
    endfunction

    function [31:0] rotword;
        input [31:0] x;
        begin
            rotword = {x[23:0], x[31:24]};
        end
    endfunction

    function [31:0] rcon_word;
        input integer idx;
        begin
            case (idx)
                1:  rcon_word = 32'h01000000;
                2:  rcon_word = 32'h02000000;
                3:  rcon_word = 32'h04000000;
                4:  rcon_word = 32'h08000000;
                5:  rcon_word = 32'h10000000;
                6:  rcon_word = 32'h20000000;
                7:  rcon_word = 32'h40000000;
                8:  rcon_word = 32'h80000000;
                9:  rcon_word = 32'h1b000000;
                10: rcon_word = 32'h36000000;
                default: rcon_word = 32'h00000000;
            endcase
        end
    endfunction

    always @* begin
        // Initial AES-128 key words, using AES column-major byte ordering.
        w[0] = key_in[127:96];
        w[1] = key_in[95:64];
        w[2] = key_in[63:32];
        w[3] = key_in[31:0];

        // Forward AES-128 key expansion.
        for (i = 4; i < 44; i = i + 1) begin
            if ((i % 4) == 0)
                w[i] = w[i-4] ^ subword(rotword(w[i-1])) ^ rcon_word(i / 4);
            else
                w[i] = w[i-4] ^ w[i-1];
        end

        /*
         * Packed for decryption consumption with low-indexed 128-bit slices:
         *
         *   round_keys[127:0]       = rk10
         *   round_keys[255:128]     = rk9
         *   ...
         *   round_keys[1407:1280]   = rk0
         *
         * This matches pipelines that select stage keys as:
         *   round_keys[stage*128 +: 128]
         */
        round_keys = {
            w[0],  w[1],  w[2],  w[3],    // rk0
            w[4],  w[5],  w[6],  w[7],    // rk1
            w[8],  w[9],  w[10], w[11],   // rk2
            w[12], w[13], w[14], w[15],   // rk3
            w[16], w[17], w[18], w[19],   // rk4
            w[20], w[21], w[22], w[23],   // rk5
            w[24], w[25], w[26], w[27],   // rk6
            w[28], w[29], w[30], w[31],   // rk7
            w[32], w[33], w[34], w[35],   // rk8
            w[36], w[37], w[38], w[39],   // rk9
            w[40], w[41], w[42], w[43]    // rk10
        };
    end

endmodule