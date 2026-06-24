`timescale 1ns/1ps

module harris_response_comb #(
    parameter IN_W   = 32,
    parameter RESP_W = 32,
    parameter K_W    = 8
) (
    input  signed [IN_W-1:0] ix2,
    input  signed [IN_W-1:0] iy2,
    input  signed [IN_W-1:0] ixiy,
    input         [K_W-1:0]  k_param,
    output        [RESP_W-1:0] response
);

    /*
     * ix2 and iy2 are squared-gradient terms and therefore represent
     * nonnegative magnitudes.  Even though the ports are signed for
     * interface consistency, treat their bit patterns as unsigned values.
     *
     * ixiy is a true signed cross-gradient term.
     */

    localparam A_W        = IN_W + 1;
    localparam PROD_W     = 2 * A_W;

    localparam DET_W      = PROD_W + 1;

    localparam TR_W       = IN_W + 2;
    localparam TRSQ_W     = 2 * TR_W;

    localparam K_EXT_W    = K_W + 1;
    localparam K_MUL_W    = TRSQ_W + K_EXT_W;

    localparam H_BASE_W   = (DET_W > K_MUL_W) ? (DET_W + 1) : (K_MUL_W + 1);
    localparam HARRIS_W   = (H_BASE_W > (RESP_W + 1)) ? H_BASE_W : (RESP_W + 1);

    wire signed [A_W-1:0] ix2_pos;
    wire signed [A_W-1:0] iy2_pos;
    wire signed [A_W-1:0] ixiy_s;

    assign ix2_pos  = {1'b0, ix2};
    assign iy2_pos  = {1'b0, iy2};
    assign ixiy_s   = {ixiy[IN_W-1], ixiy};

    wire signed [PROD_W-1:0] ix2_iy2_prod;
    wire signed [PROD_W-1:0] ixiy_sq_prod;

    assign ix2_iy2_prod = ix2_pos * iy2_pos;
    assign ixiy_sq_prod = ixiy_s  * ixiy_s;

    wire signed [HARRIS_W-1:0] ix2_iy2_ext;
    wire signed [HARRIS_W-1:0] ixiy_sq_ext;

    assign ix2_iy2_ext = {{(HARRIS_W-PROD_W){ix2_iy2_prod[PROD_W-1]}}, ix2_iy2_prod};
    assign ixiy_sq_ext = {{(HARRIS_W-PROD_W){ixiy_sq_prod[PROD_W-1]}}, ixiy_sq_prod};

    wire signed [HARRIS_W-1:0] det_full;

    assign det_full = ix2_iy2_ext - ixiy_sq_ext;

    wire signed [TR_W-1:0] ix2_trace_ext;
    wire signed [TR_W-1:0] iy2_trace_ext;
    wire signed [TR_W-1:0] trace;

    assign ix2_trace_ext = {{(TR_W-A_W){1'b0}}, ix2_pos};
    assign iy2_trace_ext = {{(TR_W-A_W){1'b0}}, iy2_pos};

    assign trace = ix2_trace_ext + iy2_trace_ext;

    wire signed [TRSQ_W-1:0] trace_sq;

    assign trace_sq = trace * trace;

    wire signed [K_EXT_W-1:0] k_ext;
    assign k_ext = {1'b0, k_param};

    wire signed [K_MUL_W-1:0] k_trace_sq_full;

    assign k_trace_sq_full = k_ext * trace_sq;

    wire signed [K_MUL_W-1:0] k_trace_sq_scaled;

    assign k_trace_sq_scaled = k_trace_sq_full >>> K_W;

    wire signed [HARRIS_W-1:0] k_term_ext;

    assign k_term_ext = {{(HARRIS_W-K_MUL_W){k_trace_sq_scaled[K_MUL_W-1]}},
                         k_trace_sq_scaled};

    wire signed [HARRIS_W-1:0] r_full;

    assign r_full = det_full - k_term_ext;

    wire signed [HARRIS_W-1:0] resp_max_ext;

    assign resp_max_ext = {{(HARRIS_W-RESP_W){1'b0}}, {RESP_W{1'b1}}};

    assign response =
        (r_full <= 0)           ? {RESP_W{1'b0}} :
        (r_full > resp_max_ext) ? {RESP_W{1'b1}} :
                                  r_full[RESP_W-1:0];

endmodule