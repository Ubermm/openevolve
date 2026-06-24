`timescale 1ns/1ps

module fir_coeff_rom #(
    parameter TAP_CNT = 101,
    parameter COEFF_W = 16
) (
    output [(50*COEFF_W)-1:0] coeff_pair_flat,
    output [COEFF_W-1:0]      coeff_center
);

    localparam integer PAIR_CNT = 50;

    function signed [COEFF_W-1:0] coeff_value;
        input integer idx;
        begin
            case (idx)
                0:   coeff_value = 16'sd0;
                1:   coeff_value = -16'sd2;
                2:   coeff_value = -16'sd5;
                3:   coeff_value = -16'sd7;
                4:   coeff_value = -16'sd10;
                5:   coeff_value = -16'sd14;
                6:   coeff_value = -16'sd18;
                7:   coeff_value = -16'sd23;
                8:   coeff_value = -16'sd29;
                9:   coeff_value = -16'sd35;
                10:  coeff_value = -16'sd41;
                11:  coeff_value = -16'sd49;
                12:  coeff_value = -16'sd56;
                13:  coeff_value = -16'sd63;
                14:  coeff_value = -16'sd70;
                15:  coeff_value = -16'sd76;
                16:  coeff_value = -16'sd81;
                17:  coeff_value = -16'sd85;
                18:  coeff_value = -16'sd86;
                19:  coeff_value = -16'sd85;
                20:  coeff_value = -16'sd81;
                21:  coeff_value = -16'sd73;
                22:  coeff_value = -16'sd62;
                23:  coeff_value = -16'sd46;
                24:  coeff_value = -16'sd26;
                25:  coeff_value = 16'sd0;
                26:  coeff_value = 16'sd31;
                27:  coeff_value = 16'sd67;
                28:  coeff_value = 16'sd109;
                29:  coeff_value = 16'sd156;
                30:  coeff_value = 16'sd208;
                31:  coeff_value = 16'sd266;
                32:  coeff_value = 16'sd327;
                33:  coeff_value = 16'sd393;
                34:  coeff_value = 16'sd462;
                35:  coeff_value = 16'sd534;
                36:  coeff_value = 16'sd607;
                37:  coeff_value = 16'sd682;
                38:  coeff_value = 16'sd756;
                39:  coeff_value = 16'sd830;
                40:  coeff_value = 16'sd901;
                41:  coeff_value = 16'sd970;
                42:  coeff_value = 16'sd1034;
                43:  coeff_value = 16'sd1094;
                44:  coeff_value = 16'sd1147;
                45:  coeff_value = 16'sd1194;
                46:  coeff_value = 16'sd1233;
                47:  coeff_value = 16'sd1265;
                48:  coeff_value = 16'sd1287;
                49:  coeff_value = 16'sd1301;
                50:  coeff_value = 16'sd1306;
                51:  coeff_value = 16'sd1301;
                52:  coeff_value = 16'sd1287;
                53:  coeff_value = 16'sd1265;
                54:  coeff_value = 16'sd1233;
                55:  coeff_value = 16'sd1194;
                56:  coeff_value = 16'sd1147;
                57:  coeff_value = 16'sd1094;
                58:  coeff_value = 16'sd1034;
                59:  coeff_value = 16'sd970;
                60:  coeff_value = 16'sd901;
                61:  coeff_value = 16'sd830;
                62:  coeff_value = 16'sd756;
                63:  coeff_value = 16'sd682;
                64:  coeff_value = 16'sd607;
                65:  coeff_value = 16'sd534;
                66:  coeff_value = 16'sd462;
                67:  coeff_value = 16'sd393;
                68:  coeff_value = 16'sd327;
                69:  coeff_value = 16'sd266;
                70:  coeff_value = 16'sd208;
                71:  coeff_value = 16'sd156;
                72:  coeff_value = 16'sd109;
                73:  coeff_value = 16'sd67;
                74:  coeff_value = 16'sd31;
                75:  coeff_value = 16'sd0;
                76:  coeff_value = -16'sd26;
                77:  coeff_value = -16'sd46;
                78:  coeff_value = -16'sd62;
                79:  coeff_value = -16'sd73;
                80:  coeff_value = -16'sd81;
                81:  coeff_value = -16'sd85;
                82:  coeff_value = -16'sd86;
                83:  coeff_value = -16'sd85;
                84:  coeff_value = -16'sd81;
                85:  coeff_value = -16'sd76;
                86:  coeff_value = -16'sd70;
                87:  coeff_value = -16'sd63;
                88:  coeff_value = -16'sd56;
                89:  coeff_value = -16'sd49;
                90:  coeff_value = -16'sd41;
                91:  coeff_value = -16'sd35;
                92:  coeff_value = -16'sd29;
                93:  coeff_value = -16'sd23;
                94:  coeff_value = -16'sd18;
                95:  coeff_value = -16'sd14;
                96:  coeff_value = -16'sd10;
                97:  coeff_value = -16'sd7;
                98:  coeff_value = -16'sd5;
                99:  coeff_value = -16'sd2;
                100: coeff_value = 16'sd0;
                default: coeff_value = {COEFF_W{1'b0}};
            endcase
        end
    endfunction

    genvar i;
    generate
        for (i = 0; i < PAIR_CNT; i = i + 1) begin : gen_coeff_pair_flat
            assign coeff_pair_flat[i*COEFF_W +: COEFF_W] = coeff_value(i);
        end
    endgenerate

    assign coeff_center = coeff_value(50);

endmodule