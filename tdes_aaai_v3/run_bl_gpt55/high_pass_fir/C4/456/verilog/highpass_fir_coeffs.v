`timescale 1ns/1ps

module highpass_fir_coeffs #(
    parameter TAP_CNT = 101,
    parameter COEFF_W = 16
) (
    output [COEFF_W*TAP_CNT-1:0] coeffs_flat
);

    function [COEFF_W-1:0] coeff_value;
        input integer idx;
        begin
            case (idx)
                0:   coeff_value = 16'sd0;
                1:   coeff_value = 16'sd10;
                2:   coeff_value = 16'sd17;
                3:   coeff_value = 16'sd19;
                4:   coeff_value = 16'sd13;
                5:   coeff_value = 16'sd0;
                6:   coeff_value = -16'sd16;
                7:   coeff_value = -16'sd29;
                8:   coeff_value = -16'sd32;
                9:   coeff_value = -16'sd23;
                10:  coeff_value = 16'sd0;
                11:  coeff_value = 16'sd29;
                12:  coeff_value = 16'sd53;
                13:  coeff_value = 16'sd60;
                14:  coeff_value = 16'sd42;
                15:  coeff_value = 16'sd0;
                16:  coeff_value = -16'sd53;
                17:  coeff_value = -16'sd96;
                18:  coeff_value = -16'sd107;
                19:  coeff_value = -16'sd73;
                20:  coeff_value = 16'sd0;
                21:  coeff_value = 16'sd90;
                22:  coeff_value = 16'sd161;
                23:  coeff_value = 16'sd177;
                24:  coeff_value = 16'sd121;
                25:  coeff_value = 16'sd0;
                26:  coeff_value = -16'sd145;
                27:  coeff_value = -16'sd258;
                28:  coeff_value = -16'sd282;
                29:  coeff_value = -16'sd191;
                30:  coeff_value = 16'sd0;
                31:  coeff_value = 16'sd229;
                32:  coeff_value = 16'sd406;
                33:  coeff_value = 16'sd444;
                34:  coeff_value = 16'sd301;
                35:  coeff_value = 16'sd0;
                36:  coeff_value = -16'sd365;
                37:  coeff_value = -16'sd652;
                38:  coeff_value = -16'sd724;
                39:  coeff_value = -16'sd499;
                40:  coeff_value = 16'sd0;
                41:  coeff_value = 16'sd633;
                42:  coeff_value = 16'sd1170;
                43:  coeff_value = 16'sd1355;
                44:  coeff_value = 16'sd989;
                45:  coeff_value = 16'sd0;
                46:  coeff_value = -16'sd1511;
                47:  coeff_value = -16'sd3280;
                48:  coeff_value = -16'sd4943;
                49:  coeff_value = -16'sd6126;
                50:  coeff_value = 16'sd26219;
                51:  coeff_value = -16'sd6126;
                52:  coeff_value = -16'sd4943;
                53:  coeff_value = -16'sd3280;
                54:  coeff_value = -16'sd1511;
                55:  coeff_value = 16'sd0;
                56:  coeff_value = 16'sd989;
                57:  coeff_value = 16'sd1355;
                58:  coeff_value = 16'sd1170;
                59:  coeff_value = 16'sd633;
                60:  coeff_value = 16'sd0;
                61:  coeff_value = -16'sd499;
                62:  coeff_value = -16'sd724;
                63:  coeff_value = -16'sd652;
                64:  coeff_value = -16'sd365;
                65:  coeff_value = 16'sd0;
                66:  coeff_value = 16'sd301;
                67:  coeff_value = 16'sd444;
                68:  coeff_value = 16'sd406;
                69:  coeff_value = 16'sd229;
                70:  coeff_value = 16'sd0;
                71:  coeff_value = -16'sd191;
                72:  coeff_value = -16'sd282;
                73:  coeff_value = -16'sd258;
                74:  coeff_value = -16'sd145;
                75:  coeff_value = 16'sd0;
                76:  coeff_value = 16'sd121;
                77:  coeff_value = 16'sd177;
                78:  coeff_value = 16'sd161;
                79:  coeff_value = 16'sd90;
                80:  coeff_value = 16'sd0;
                81:  coeff_value = -16'sd73;
                82:  coeff_value = -16'sd107;
                83:  coeff_value = -16'sd96;
                84:  coeff_value = -16'sd53;
                85:  coeff_value = 16'sd0;
                86:  coeff_value = 16'sd42;
                87:  coeff_value = 16'sd60;
                88:  coeff_value = 16'sd53;
                89:  coeff_value = 16'sd29;
                90:  coeff_value = 16'sd0;
                91:  coeff_value = -16'sd23;
                92:  coeff_value = -16'sd32;
                93:  coeff_value = -16'sd29;
                94:  coeff_value = -16'sd16;
                95:  coeff_value = 16'sd0;
                96:  coeff_value = 16'sd13;
                97:  coeff_value = 16'sd19;
                98:  coeff_value = 16'sd17;
                99:  coeff_value = 16'sd10;
                100: coeff_value = 16'sd0;
                default: coeff_value = {COEFF_W{1'b0}};
            endcase
        end
    endfunction

    genvar i;
    generate
        for (i = 0; i < TAP_CNT; i = i + 1) begin : gen_coeff_pack
            assign coeffs_flat[i*COEFF_W +: COEFF_W] = coeff_value(i);
        end
    endgenerate

endmodule