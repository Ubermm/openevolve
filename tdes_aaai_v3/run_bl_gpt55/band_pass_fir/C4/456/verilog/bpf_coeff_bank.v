module bpf_coeff_bank #(
    parameter TAP_CNT = 101,
    parameter COEFF_W = 16
) (
    output [TAP_CNT*COEFF_W-1:0] coeff_flat
);

function signed [COEFF_W-1:0] coeff_value;
    input integer idx;
    begin
        case (idx)
            0:   coeff_value = 16'sd16;
            1:   coeff_value = 16'sd10;
            2:   coeff_value = 16'sd6;
            3:   coeff_value = 16'sd2;
            4:   coeff_value = 16'sd0;
            5:   coeff_value = 16'sd1;
            6:   coeff_value = 16'sd5;
            7:   coeff_value = 16'sd13;
            8:   coeff_value = 16'sd26;
            9:   coeff_value = 16'sd42;
            10:  coeff_value = 16'sd59;
            11:  coeff_value = 16'sd77;
            12:  coeff_value = 16'sd90;
            13:  coeff_value = 16'sd97;
            14:  coeff_value = 16'sd93;
            15:  coeff_value = 16'sd77;
            16:  coeff_value = 16'sd47;
            17:  coeff_value = 16'sd5;
            18:  coeff_value = -16'sd45;
            19:  coeff_value = -16'sd99;
            20:  coeff_value = -16'sd149;
            21:  coeff_value = -16'sd187;
            22:  coeff_value = -16'sd207;
            23:  coeff_value = -16'sd204;
            24:  coeff_value = -16'sd178;
            25:  coeff_value = -16'sd132;
            26:  coeff_value = -16'sd73;
            27:  coeff_value = -16'sd14;
            28:  coeff_value = 16'sd31;
            29:  coeff_value = 16'sd46;
            30:  coeff_value = 16'sd16;
            31:  coeff_value = -16'sd67;
            32:  coeff_value = -16'sd208;
            33:  coeff_value = -16'sd403;
            34:  coeff_value = -16'sd638;
            35:  coeff_value = -16'sd891;
            36:  coeff_value = -16'sd1134;
            37:  coeff_value = -16'sd1333;
            38:  coeff_value = -16'sd1455;
            39:  coeff_value = -16'sd1471;
            40:  coeff_value = -16'sd1359;
            41:  coeff_value = -16'sd1111;
            42:  coeff_value = -16'sd730;
            43:  coeff_value = -16'sd235;
            44:  coeff_value = 16'sd341;
            45:  coeff_value = 16'sd955;
            46:  coeff_value = 16'sd1555;
            47:  coeff_value = 16'sd2091;
            48:  coeff_value = 16'sd2513;
            49:  coeff_value = 16'sd2784;
            50:  coeff_value = 16'sd2877;
            51:  coeff_value = 16'sd2784;
            52:  coeff_value = 16'sd2513;
            53:  coeff_value = 16'sd2091;
            54:  coeff_value = 16'sd1555;
            55:  coeff_value = 16'sd955;
            56:  coeff_value = 16'sd341;
            57:  coeff_value = -16'sd235;
            58:  coeff_value = -16'sd730;
            59:  coeff_value = -16'sd1111;
            60:  coeff_value = -16'sd1359;
            61:  coeff_value = -16'sd1471;
            62:  coeff_value = -16'sd1455;
            63:  coeff_value = -16'sd1333;
            64:  coeff_value = -16'sd1134;
            65:  coeff_value = -16'sd891;
            66:  coeff_value = -16'sd638;
            67:  coeff_value = -16'sd403;
            68:  coeff_value = -16'sd208;
            69:  coeff_value = -16'sd67;
            70:  coeff_value = 16'sd16;
            71:  coeff_value = 16'sd46;
            72:  coeff_value = 16'sd31;
            73:  coeff_value = -16'sd14;
            74:  coeff_value = -16'sd73;
            75:  coeff_value = -16'sd132;
            76:  coeff_value = -16'sd178;
            77:  coeff_value = -16'sd204;
            78:  coeff_value = -16'sd207;
            79:  coeff_value = -16'sd187;
            80:  coeff_value = -16'sd149;
            81:  coeff_value = -16'sd99;
            82:  coeff_value = -16'sd45;
            83:  coeff_value = 16'sd5;
            84:  coeff_value = 16'sd47;
            85:  coeff_value = 16'sd77;
            86:  coeff_value = 16'sd93;
            87:  coeff_value = 16'sd97;
            88:  coeff_value = 16'sd90;
            89:  coeff_value = 16'sd77;
            90:  coeff_value = 16'sd59;
            91:  coeff_value = 16'sd42;
            92:  coeff_value = 16'sd26;
            93:  coeff_value = 16'sd13;
            94:  coeff_value = 16'sd5;
            95:  coeff_value = 16'sd1;
            96:  coeff_value = 16'sd0;
            97:  coeff_value = 16'sd2;
            98:  coeff_value = 16'sd6;
            99:  coeff_value = 16'sd10;
            100: coeff_value = 16'sd16;
            default: coeff_value = {COEFF_W{1'b0}};
        endcase
    end
endfunction

genvar i;
generate
    for (i = 0; i < TAP_CNT; i = i + 1) begin : gen_coeff_flat
        assign coeff_flat[i*COEFF_W +: COEFF_W] = coeff_value(i);
    end
endgenerate

endmodule