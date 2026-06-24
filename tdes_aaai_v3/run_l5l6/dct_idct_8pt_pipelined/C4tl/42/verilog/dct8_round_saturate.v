`timescale 1ns/1ps

module dct8_round_saturate #(
    parameter IN_W  = 32,
    parameter OUT_W = 18,
    parameter SHIFT = 14
) (
    input  signed [IN_W-1:0]  in_value,
    output signed [OUT_W-1:0] out_value
);

    /*
     * Use a work width larger than both input and output ranges so that:
     *   - sign extension is safe
     *   - rounding addition cannot overflow
     *   - saturation constants are represented with a non-sign MSB
     */
    localparam integer WORK_W = ((IN_W > OUT_W) ? IN_W : OUT_W) + 2;

    localparam signed [WORK_W-1:0] ONE = {{(WORK_W-1){1'b0}}, 1'b1};

    localparam signed [WORK_W-1:0] SAT_MAX =
        (ONE <<< (OUT_W-1)) - ONE;

    localparam signed [WORK_W-1:0] SAT_MIN =
        -(ONE <<< (OUT_W-1));

    wire signed [WORK_W-1:0] in_ext;
    wire signed [WORK_W-1:0] scaled;

    assign in_ext = {{(WORK_W-IN_W){in_value[IN_W-1]}}, in_value};

    generate
        if (SHIFT > 0) begin : gen_round_shift
            localparam signed [WORK_W-1:0] ROUND_HALF =
                (ONE <<< (SHIFT-1));

            wire signed [WORK_W-1:0] round_bias;
            wire signed [WORK_W-1:0] rounded;

            /*
             * Correct signed rounding before arithmetic shift.
             *
             * Arithmetic right shift floors negative values, so negative inputs
             * must use HALF-1 rather than subtracting HALF.
             *
             * This implements round-to-nearest with ties away from zero.
             */
            assign round_bias = in_ext[WORK_W-1] ?
                                (ROUND_HALF - ONE) :
                                ROUND_HALF;

            assign rounded = in_ext + round_bias;
            assign scaled  = rounded >>> SHIFT;
        end else begin : gen_no_shift
            assign scaled = in_ext;
        end
    endgenerate

    assign out_value =
        (scaled > SAT_MAX) ? {1'b0, {(OUT_W-1){1'b1}}} :
        (scaled < SAT_MIN) ? {1'b1, {(OUT_W-1){1'b0}}} :
                             scaled[OUT_W-1:0];

endmodule