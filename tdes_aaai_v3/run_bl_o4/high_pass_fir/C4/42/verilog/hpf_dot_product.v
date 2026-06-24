module hpf_dot_product #(
    parameter integer TAP_CNT = 101,
    parameter integer DATA_W  = 20,
    parameter integer COEFF_W = 16
)(
    input  wire signed [DATA_W*TAP_CNT-1:0] taps_flat,
    output reg  signed [63:0]               sum_out
);

    // Flattened coefficient vector (MSB block = coeff[0], LSB block = coeff[TAP_CNT-1])
    localparam signed [TAP_CNT*COEFF_W-1:0] coeffs_flat = {
        16'sd0,     16'sd10,    16'sd17,    16'sd19,    16'sd13,
        16'sd0,     16'sd-16,   16'sd-29,   16'sd-32,   16'sd-23,
        16'sd0,     16'sd29,    16'sd53,    16'sd60,    16'sd42,
        16'sd0,     16'sd-53,   16'sd-96,   16'sd-107,  16'sd-73,
        16'sd0,     16'sd90,    16'sd161,   16'sd177,   16'sd121,
        16'sd0,     16'sd-145,  16'sd-258,  16'sd-282,  16'sd-191,
        16'sd0,     16'sd229,   16'sd406,   16'sd444,   16'sd301,
        16'sd0,     16'sd-365,  16'sd-652,  16'sd-724,  16'sd-499,
        16'sd0,     16'sd633,   16'sd1170,  16'sd1355,  16'sd989,
        16'sd0,     16'sd-1511, 16'sd-3280, 16'sd-4943, 16'sd-6126,
        16'sd26219, 16'sd-6126, 16'sd-4943, 16'sd-3280, 16'sd-1511,
        16'sd0,     16'sd989,   16'sd1355,  16'sd1170,  16'sd633,
        16'sd0,     16'sd-499,  16'sd-724,  16'sd-652,  16'sd-365,
        16'sd0,     16'sd301,   16'sd444,   16'sd406,   16'sd229,
        16'sd0,     16'sd-191,  16'sd-282,  16'sd-258,  16'sd-145,
        16'sd0,     16'sd121,   16'sd177,   16'sd161,   16'sd90,
        16'sd0,     16'sd-73,   16'sd-107,  16'sd-96,   16'sd-53,
        16'sd0,     16'sd42,    16'sd60,    16'sd53,    16'sd29,
        16'sd0,     16'sd-23,   16'sd-32,   16'sd-29,   16'sd-16,
        16'sd0,     16'sd13,    16'sd19,    16'sd17,    16'sd10,
        16'sd0
    };

    integer i;
    always @* begin
        sum_out = 64'sd0;
        // Multiply-accumulate: extract each tap and its matching coefficient
        for (i = 0; i < TAP_CNT; i = i + 1) begin
            // extract DATA_W-bit tap i
            // extract COEFF_W-bit coeff[i] from flattened vector
            sum_out = sum_out
                + $signed(taps_flat[i*DATA_W +: DATA_W])
                * $signed(coeffs_flat[COEFF_W*(TAP_CNT-i) - 1 -: COEFF_W]);
        end
    end

endmodule