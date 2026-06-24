`timescale 1ns/1ps

module fir_symmetric_mac #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter COEFF_W = 16,
    parameter ACC_W   = 64
) (
    input  [((TAP_CNT-1)/2)*(DATA_W+1)-1:0] pair_sums_flat,
    input  [DATA_W-1:0]                     center_sample,
    input  [TAP_CNT*COEFF_W-1:0]            coeff_flat,
    output signed [ACC_W-1:0]               acc_out
);

    localparam HALF_TAPS = (TAP_CNT-1)/2;
    localparam PAIR_W    = DATA_W + 1;

    reg signed [ACC_W-1:0]   acc_reg;
    reg signed [PAIR_W-1:0]  pair_sum;
    reg signed [DATA_W-1:0]  center_s;
    integer                  i;

    function signed [COEFF_W-1:0] coeff_lut;
        input integer idx;
        begin
            case (idx)
                0:   coeff_lut = 16'sd0;
                1:   coeff_lut = -16'sd2;
                2:   coeff_lut = -16'sd5;
                3:   coeff_lut = -16'sd7;
                4:   coeff_lut = -16'sd10;
                5:   coeff_lut = -16'sd14;
                6:   coeff_lut = -16'sd18;
                7:   coeff_lut = -16'sd23;
                8:   coeff_lut = -16'sd29;
                9:   coeff_lut = -16'sd35;
                10:  coeff_lut = -16'sd41;
                11:  coeff_lut = -16'sd49;
                12:  coeff_lut = -16'sd56;
                13:  coeff_lut = -16'sd63;
                14:  coeff_lut = -16'sd70;
                15:  coeff_lut = -16'sd76;
                16:  coeff_lut = -16'sd81;
                17:  coeff_lut = -16'sd85;
                18:  coeff_lut = -16'sd86;
                19:  coeff_lut = -16'sd85;
                20:  coeff_lut = -16'sd81;
                21:  coeff_lut = -16'sd73;
                22:  coeff_lut = -16'sd62;
                23:  coeff_lut = -16'sd46;
                24:  coeff_lut = -16'sd26;
                25:  coeff_lut = 16'sd0;
                26:  coeff_lut = 16'sd31;
                27:  coeff_lut = 16'sd67;
                28:  coeff_lut = 16'sd109;
                29:  coeff_lut = 16'sd156;
                30:  coeff_lut = 16'sd208;
                31:  coeff_lut = 16'sd266;
                32:  coeff_lut = 16'sd327;
                33:  coeff_lut = 16'sd393;
                34:  coeff_lut = 16'sd462;
                35:  coeff_lut = 16'sd534;
                36:  coeff_lut = 16'sd607;
                37:  coeff_lut = 16'sd682;
                38:  coeff_lut = 16'sd756;
                39:  coeff_lut = 16'sd830;
                40:  coeff_lut = 16'sd901;
                41:  coeff_lut = 16'sd970;
                42:  coeff_lut = 16'sd1034;
                43:  coeff_lut = 16'sd1094;
                44:  coeff_lut = 16'sd1147;
                45:  coeff_lut = 16'sd1194;
                46:  coeff_lut = 16'sd1233;
                47:  coeff_lut = 16'sd1265;
                48:  coeff_lut = 16'sd1287;
                49:  coeff_lut = 16'sd1301;
                50:  coeff_lut = 16'sd1306;
                51:  coeff_lut = 16'sd1301;
                52:  coeff_lut = 16'sd1287;
                53:  coeff_lut = 16'sd1265;
                54:  coeff_lut = 16'sd1233;
                55:  coeff_lut = 16'sd1194;
                56:  coeff_lut = 16'sd1147;
                57:  coeff_lut = 16'sd1094;
                58:  coeff_lut = 16'sd1034;
                59:  coeff_lut = 16'sd970;
                60:  coeff_lut = 16'sd901;
                61:  coeff_lut = 16'sd830;
                62:  coeff_lut = 16'sd756;
                63:  coeff_lut = 16'sd682;
                64:  coeff_lut = 16'sd607;
                65:  coeff_lut = 16'sd534;
                66:  coeff_lut = 16'sd462;
                67:  coeff_lut = 16'sd393;
                68:  coeff_lut = 16'sd327;
                69:  coeff_lut = 16'sd266;
                70:  coeff_lut = 16'sd208;
                71:  coeff_lut = 16'sd156;
                72:  coeff_lut = 16'sd109;
                73:  coeff_lut = 16'sd67;
                74:  coeff_lut = 16'sd31;
                75:  coeff_lut = 16'sd0;
                76:  coeff_lut = -16'sd26;
                77:  coeff_lut = -16'sd46;
                78:  coeff_lut = -16'sd62;
                79:  coeff_lut = -16'sd73;
                80:  coeff_lut = -16'sd81;
                81:  coeff_lut = -16'sd85;
                82:  coeff_lut = -16'sd86;
                83:  coeff_lut = -16'sd85;
                84:  coeff_lut = -16'sd81;
                85:  coeff_lut = -16'sd76;
                86:  coeff_lut = -16'sd70;
                87:  coeff_lut = -16'sd63;
                88:  coeff_lut = -16'sd56;
                89:  coeff_lut = -16'sd49;
                90:  coeff_lut = -16'sd41;
                91:  coeff_lut = -16'sd35;
                92:  coeff_lut = -16'sd29;
                93:  coeff_lut = -16'sd23;
                94:  coeff_lut = -16'sd18;
                95:  coeff_lut = -16'sd14;
                96:  coeff_lut = -16'sd10;
                97:  coeff_lut = -16'sd7;
                98:  coeff_lut = -16'sd5;
                99:  coeff_lut = -16'sd2;
                100: coeff_lut = 16'sd0;
                default: coeff_lut = 16'sd0;
            endcase
        end
    endfunction

    always @* begin
        acc_reg  = {ACC_W{1'b0}};
        center_s = center_sample;

        for (i = 0; i < HALF_TAPS; i = i + 1) begin
            pair_sum = pair_sums_flat[i*PAIR_W +: PAIR_W];
            acc_reg  = acc_reg + ($signed(pair_sum) * $signed(coeff_lut(i)));
        end

        acc_reg = acc_reg + ($signed(center_s) * $signed(coeff_lut(HALF_TAPS)));
    end

    assign acc_out = acc_reg;

endmodule