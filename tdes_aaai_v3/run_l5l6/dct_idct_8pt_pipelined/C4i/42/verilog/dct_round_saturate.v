`timescale 1ns/1ps

module dct_round_saturate #(
    parameter ACC_W = 32,
    parameter SHIFT = 14,
    parameter OUT_W = 18
) (
    input  signed [ACC_W-1:0] acc,
    output reg signed [OUT_W-1:0] y
);

    /*
     * Use a wide internal datapath so that:
     *   - acc can be sign-extended safely,
     *   - the rounding bias is representable,
     *   - the shifted value can be checked against OUT_W saturation limits.
     */
    localparam integer WORK_W = ACC_W + SHIFT + OUT_W + 2;

    reg signed [WORK_W-1:0] acc_ext;
    reg signed [WORK_W-1:0] round_bias;
    reg signed [WORK_W-1:0] rounded;
    reg signed [WORK_W-1:0] shifted;

    reg signed [WORK_W-1:0] sat_max;
    reg signed [WORK_W-1:0] sat_min;

    integer i;

    always @* begin
        /*
         * Sign-extend accumulator.
         */
        acc_ext = {{(WORK_W-ACC_W){acc[ACC_W-1]}}, acc};

        /*
         * Build Q-format rounding bias:
         *   SHIFT > 0 : 2^(SHIFT-1)
         *   SHIFT = 0 : 0
         */
        round_bias = {WORK_W{1'b0}};
        if (SHIFT > 0) begin
            for (i = 0; i < WORK_W; i = i + 1) begin
                if (i == SHIFT-1)
                    round_bias[i] = 1'b1;
            end
        end

        /*
         * Build signed OUT_W saturation limits in WORK_W bits.
         *
         * sat_max =  2^(OUT_W-1)-1
         * sat_min = -2^(OUT_W-1)
         */
        sat_max = {WORK_W{1'b0}};
        for (i = 0; i < OUT_W-1; i = i + 1) begin
            sat_max[i] = 1'b1;
        end

        sat_min = {WORK_W{1'b0}};
        sat_min[OUT_W-1] = 1'b1;
        for (i = OUT_W; i < WORK_W; i = i + 1) begin
            sat_min[i] = 1'b1;
        end

        /*
         * Round, arithmetic down-shift, then saturate.
         */
        rounded = acc_ext + round_bias;
        shifted = rounded >>> SHIFT;

        if (shifted > sat_max) begin
            y = {OUT_W{1'b1}};
            y[OUT_W-1] = 1'b0;
        end else if (shifted < sat_min) begin
            y = {OUT_W{1'b0}};
            y[OUT_W-1] = 1'b1;
        end else begin
            y = shifted[OUT_W-1:0];
        end
    end

endmodule