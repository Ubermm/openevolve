`timescale 1ns/1ps

module highpass_fir_mac101 #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101
) (
    input  [DATA_W*TAP_CNT-1:0] samples_flat,
    output signed [63:0]        acc_out
);

    function signed [63:0] coeff;
        input integer idx;
        begin
            case (idx)
                0:   coeff = 64'sd0;
                1:   coeff = 64'sd10;
                2:   coeff = 64'sd17;
                3:   coeff = 64'sd19;
                4:   coeff = 64'sd13;
                5:   coeff = 64'sd0;
                6:   coeff = -64'sd16;
                7:   coeff = -64'sd29;
                8:   coeff = -64'sd32;
                9:   coeff = -64'sd23;
                10:  coeff = 64'sd0;
                11:  coeff = 64'sd29;
                12:  coeff = 64'sd53;
                13:  coeff = 64'sd60;
                14:  coeff = 64'sd42;
                15:  coeff = 64'sd0;
                16:  coeff = -64'sd53;
                17:  coeff = -64'sd96;
                18:  coeff = -64'sd107;
                19:  coeff = -64'sd73;
                20:  coeff = 64'sd0;
                21:  coeff = 64'sd90;
                22:  coeff = 64'sd161;
                23:  coeff = 64'sd177;
                24:  coeff = 64'sd121;
                25:  coeff = 64'sd0;
                26:  coeff = -64'sd145;
                27:  coeff = -64'sd258;
                28:  coeff = -64'sd282;
                29:  coeff = -64'sd191;
                30:  coeff = 64'sd0;
                31:  coeff = 64'sd229;
                32:  coeff = 64'sd406;
                33:  coeff = 64'sd444;
                34:  coeff = 64'sd301;
                35:  coeff = 64'sd0;
                36:  coeff = -64'sd365;
                37:  coeff = -64'sd652;
                38:  coeff = -64'sd724;
                39:  coeff = -64'sd499;
                40:  coeff = 64'sd0;
                41:  coeff = 64'sd633;
                42:  coeff = 64'sd1170;
                43:  coeff = 64'sd1355;
                44:  coeff = 64'sd989;
                45:  coeff = 64'sd0;
                46:  coeff = -64'sd1511;
                47:  coeff = -64'sd3280;
                48:  coeff = -64'sd4943;
                49:  coeff = -64'sd6126;
                50:  coeff = 64'sd26219;
                51:  coeff = -64'sd6126;
                52:  coeff = -64'sd4943;
                53:  coeff = -64'sd3280;
                54:  coeff = -64'sd1511;
                55:  coeff = 64'sd0;
                56:  coeff = 64'sd989;
                57:  coeff = 64'sd1355;
                58:  coeff = 64'sd1170;
                59:  coeff = 64'sd633;
                60:  coeff = 64'sd0;
                61:  coeff = -64'sd499;
                62:  coeff = -64'sd724;
                63:  coeff = -64'sd652;
                64:  coeff = -64'sd365;
                65:  coeff = 64'sd0;
                66:  coeff = 64'sd301;
                67:  coeff = 64'sd444;
                68:  coeff = 64'sd406;
                69:  coeff = 64'sd229;
                70:  coeff = 64'sd0;
                71:  coeff = -64'sd191;
                72:  coeff = -64'sd282;
                73:  coeff = -64'sd258;
                74:  coeff = -64'sd145;
                75:  coeff = 64'sd0;
                76:  coeff = 64'sd121;
                77:  coeff = 64'sd177;
                78:  coeff = 64'sd161;
                79:  coeff = 64'sd90;
                80:  coeff = 64'sd0;
                81:  coeff = -64'sd73;
                82:  coeff = -64'sd107;
                83:  coeff = -64'sd96;
                84:  coeff = -64'sd53;
                85:  coeff = 64'sd0;
                86:  coeff = 64'sd42;
                87:  coeff = 64'sd60;
                88:  coeff = 64'sd53;
                89:  coeff = 64'sd29;
                90:  coeff = 64'sd0;
                91:  coeff = -64'sd23;
                92:  coeff = -64'sd32;
                93:  coeff = -64'sd29;
                94:  coeff = -64'sd16;
                95:  coeff = 64'sd0;
                96:  coeff = 64'sd13;
                97:  coeff = 64'sd19;
                98:  coeff = 64'sd17;
                99:  coeff = 64'sd10;
                100: coeff = 64'sd0;
                default: coeff = 64'sd0;
            endcase
        end
    endfunction

    wire signed [63:0] sum [0:101];

    assign sum[0] = 64'sd0;

    genvar i;
    generate
        for (i = 0; i < 101; i = i + 1) begin : gen_mac
            wire signed [DATA_W-1:0] sample;
            wire signed [63:0]       sample_ext;
            wire signed [63:0]       product;

            assign sample     = samples_flat[i*DATA_W +: DATA_W];
            assign sample_ext = {{(64-DATA_W){sample[DATA_W-1]}}, sample};
            assign product    = sample_ext * coeff(i);
            assign sum[i+1]   = sum[i] + product;
        end
    endgenerate

    assign acc_out = sum[101];

endmodule