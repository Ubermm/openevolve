`timescale 1ns/1ps

module grad_products #(
    parameter GRAD_W = 16,
    parameter PROD_W = 32
) (
    input  signed [GRAD_W-1:0] gx,
    input  signed [GRAD_W-1:0] gy,
    output        [PROD_W-1:0] ix2,
    output        [PROD_W-1:0] iy2,
    output signed [PROD_W-1:0] ixiy
);

    localparam FULL_W = 2 * GRAD_W;

    /*
     * Explicitly sign-extend operands before multiplication.
     * This avoids tool-dependent surprises from expression sizing and
     * guarantees that the computed product has at least FULL_W useful bits.
     */
    wire signed [FULL_W-1:0] gx_ext;
    wire signed [FULL_W-1:0] gy_ext;

    assign gx_ext = {{GRAD_W{gx[GRAD_W-1]}}, gx};
    assign gy_ext = {{GRAD_W{gy[GRAD_W-1]}}, gy};

    wire signed [FULL_W-1:0] gx_sq_full;
    wire signed [FULL_W-1:0] gy_sq_full;
    wire signed [FULL_W-1:0] xy_full;

    assign gx_sq_full = gx_ext * gx_ext;
    assign gy_sq_full = gy_ext * gy_ext;
    assign xy_full    = gx_ext * gy_ext;

    generate
        if (PROD_W < FULL_W) begin : gen_truncate
            assign ix2  = gx_sq_full[PROD_W-1:0];
            assign iy2  = gy_sq_full[PROD_W-1:0];
            assign ixiy = xy_full[PROD_W-1:0];
        end else if (PROD_W == FULL_W) begin : gen_same_width
            assign ix2  = gx_sq_full;
            assign iy2  = gy_sq_full;
            assign ixiy = xy_full;
        end else begin : gen_extend
            assign ix2  = {{(PROD_W-FULL_W){1'b0}}, gx_sq_full};
            assign iy2  = {{(PROD_W-FULL_W){1'b0}}, gy_sq_full};
            assign ixiy = {{(PROD_W-FULL_W){xy_full[FULL_W-1]}}, xy_full};
        end
    endgenerate

endmodule