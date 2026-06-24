module coeff_store #(
    parameter COEFF_W = 16,
    parameter TAP_CNT  = 101
) (
    output wire signed [COEFF_W*TAP_CNT-1:0] coeffs
);

    // Flat vector of 101 signed 16-bit FIR coefficients (linear‐phase symmetric)
    assign coeffs = {
        16'sd0,    16'sd-2,   16'sd-5,   16'sd-7,    16'sd-10,
        16'sd-14,  16'sd-18,  16'sd-23,  16'sd-29,   16'sd-35,
        16'sd-41,  16'sd-49,  16'sd-56,  16'sd-63,   16'sd-70,
        16'sd-76,  16'sd-81,  16'sd-85,  16'sd-86,   16'sd-85,
        16'sd-81,  16'sd-73,  16'sd-62,  16'sd-46,   16'sd-26,
        16'sd0,    16'sd31,   16'sd67,   16'sd109,   16'sd156,
        16'sd208,  16'sd266,  16'sd327,  16'sd393,   16'sd462,
        16'sd534,  16'sd607,  16'sd682,  16'sd756,   16'sd830,
        16'sd901,  16'sd970,  16'sd1034, 16'sd1094,  16'sd1147,
        16'sd1194, 16'sd1233, 16'sd1265, 16'sd1287,  16'sd1301,
        16'sd1306, 16'sd1301, 16'sd1287, 16'sd1265,  16'sd1233,
        16'sd1194, 16'sd1147, 16'sd1094, 16'sd1034,  16'sd970,
        16'sd901,  16'sd830,  16'sd756,  16'sd682,   16'sd607,
        16'sd534,  16'sd462,  16'sd393,  16'sd327,   16'sd266,
        16'sd208,  16'sd156,  16'sd109,  16'sd67,    16'sd31,
        16'sd0,    16'sd-26,  16'sd-46,  16'sd-62,   16'sd-73,
        16'sd-81,  16'sd-85,  16'sd-86,  16'sd-85,   16'sd-81,
        16'sd-76,  16'sd-70,  16'sd-63,  16'sd-56,   16'sd-49,
        16'sd-41,  16'sd-35,  16'sd-29,  16'sd-23,   16'sd-18,
        16'sd-14,  16'sd-10,  16'sd-7,   16'sd-5,    16'sd-2,
        16'sd0
    };

endmodule