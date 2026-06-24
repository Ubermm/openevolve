`timescale 1ns/1ps

module harris_threshold #(
    parameter RESP_W = 32
) (
    input  signed [RESP_W-1:0] response,
    input         [RESP_W-1:0] threshold,
    output                    is_corner
);

    /*
     * Harris threshold decision:
     *
     *   is_corner = 1 iff response > threshold
     *
     * response is signed, while threshold is an unsigned positive value.
     * A negative response can never exceed a positive threshold, so guard
     * the comparison with the sign bit check.  The magnitude comparison is
     * then done using explicit zero-extension to avoid Verilog mixed
     * signed/unsigned comparison ambiguity.
     */

    assign is_corner =
        (~response[RESP_W-1]) &&
        ({1'b0, response} > {1'b0, threshold});

endmodule