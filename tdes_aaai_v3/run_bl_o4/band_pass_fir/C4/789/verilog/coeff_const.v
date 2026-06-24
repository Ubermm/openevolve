module coeff_const #(
    parameter integer IDX = 0
) (
    output reg signed [15:0] coeff
);

    always @* begin
        case (IDX)
            0  : coeff = 16'sd16;
            1  : coeff = 16'sd10;
            2  : coeff = 16'sd6;
            3  : coeff = 16'sd2;
            4  : coeff = 16'sd0;
            5  : coeff = 16'sd1;
            6  : coeff = 16'sd5;
            7  : coeff = 16'sd13;
            8  : coeff = 16'sd26;
            9  : coeff = 16'sd42;
            10 : coeff = 16'sd59;
            11 : coeff = 16'sd77;
            12 : coeff = 16'sd90;
            13 : coeff = 16'sd97;
            14 : coeff = 16'sd93;
            15 : coeff = 16'sd77;
            16 : coeff = 16'sd47;
            17 : coeff = 16'sd5;
            18 : coeff = -16'sd45;
            19 : coeff = -16'sd99;
            20 : coeff = -16'sd149;
            21 : coeff = -16'sd187;
            22 : coeff = -16'sd207;
            23 : coeff = -16'sd204;
            24 : coeff = -16'sd178;
            25 : coeff = -16'sd132;
            26 : coeff = -16'sd73;
            27 : coeff = -16'sd14;
            28 : coeff = 16'sd31;
            29 : coeff = 16'sd46;
            30 : coeff = 16'sd16;
            31 : coeff = -16'sd67;
            32 : coeff = -16'sd208;
            33 : coeff = -16'sd403;
            34 : coeff = -16'sd638;
            35 : coeff = -16'sd891;
            36 : coeff = -16'sd1134;
            37 : coeff = -16'sd1333;
            38 : coeff = -16'sd1455;
            39 : coeff = -16'sd1471;
            40 : coeff = -16'sd1359;
            41 : coeff = -16'sd1111;
            42 : coeff = -16'sd730;
            43 : coeff = -16'sd235;
            44 : coeff = 16'sd341;
            45 : coeff = 16'sd955;
            46 : coeff = 16'sd1555;
            47 : coeff = 16'sd2091;
            48 : coeff = 16'sd2513;
            49 : coeff = 16'sd2784;
            50 : coeff = 16'sd2877;
            51 : coeff = 16'sd2784;
            52 : coeff = 16'sd2513;
            53 : coeff = 16'sd2091;
            54 : coeff = 16'sd1555;
            55 : coeff = 16'sd955;
            56 : coeff = 16'sd341;
            57 : coeff = -16'sd235;
            58 : coeff = -16'sd730;
            59 : coeff = -16'sd1111;
            60 : coeff = -16'sd1359;
            61 : coeff = -16'sd1471;
            62 : coeff = -16'sd1455;
            63 : coeff = -16'sd1333;
            64 : coeff = -16'sd1134;
            65 : coeff = -16'sd891;
            66 : coeff = -16'sd638;
            67 : coeff = -16'sd403;
            68 : coeff = -16'sd208;
            69 : coeff = -16'sd67;
            70 : coeff = 16'sd16;
            71 : coeff = 16'sd46;
            72 : coeff = 16'sd31;
            73 : coeff = -16'sd14;
            74 : coeff = -16'sd73;
            75 : coeff = -16'sd132;
            76 : coeff = -16'sd178;
            77 : coeff = -16'sd204;
            78 : coeff = -16'sd207;
            79 : coeff = -16'sd187;
            80 : coeff = -16'sd149;
            81 : coeff = -16'sd99;
            82 : coeff = -16'sd45;
            83 : coeff = 16'sd5;
            84 : coeff = 16'sd47;
            85 : coeff = 16'sd77;
            86 : coeff = 16'sd93;
            87 : coeff = 16'sd97;
            88 : coeff = 16'sd90;
            89 : coeff = 16'sd77;
            90 : coeff = 16'sd59;
            91 : coeff = 16'sd42;
            92 : coeff = 16'sd26;
            93 : coeff = 16'sd13;
            94 : coeff = 16'sd5;
            95 : coeff = 16'sd1;
            96 : coeff = 16'sd0;
            97 : coeff = 16'sd2;
            98 : coeff = 16'sd6;
            99 : coeff = 16'sd10;
            100: coeff = 16'sd16;
            default: coeff = 16'sd0;
        endcase
    end

endmodule