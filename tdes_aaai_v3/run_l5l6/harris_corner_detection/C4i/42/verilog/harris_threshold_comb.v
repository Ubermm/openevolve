`timescale 1ns/1ps

module harris_threshold_comb #(
    parameter RESP_W = 32
) (
    input  [RESP_W-1:0] response,
    input  [RESP_W-1:0] threshold,
    output              is_corner
);

    /*
     * Harris response R may be negative:
     *
     *   R = det - k * trace^2
     *
     * Therefore response must be compared as a signed two's-complement value.
     * The threshold is interpreted in the same signed response domain.
     *
     * Corner decision is strictly greater-than, matching:
     *
     *   is_corner = 1 if R > threshold, else 0
     */
    assign is_corner = ($signed(response) > $signed(threshold));

endmodule