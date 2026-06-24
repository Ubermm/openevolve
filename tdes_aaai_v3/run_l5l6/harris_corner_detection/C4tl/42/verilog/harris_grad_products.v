`timescale 1ns/1ps

module harris_grad_products #(
    parameter GRAD_W = 16
) (
    input  signed [GRAD_W-1:0] gx,
    input  signed [GRAD_W-1:0] gy,
    output reg signed [(2*GRAD_W)-1:0] ix2,
    output reg signed [(2*GRAD_W)-1:0] iy2,
    output reg signed [(2*GRAD_W)-1:0] ixiy
);

    localparam PROD_W = 2 * GRAD_W;

    /*
     * Explicitly widen the signed operands before multiplication.
     *
     * This guarantees that the products are computed with enough precision
     * for the full 2*GRAD_W result, independent of simulator/synthesis
     * expression-sizing behavior.
     */
    wire signed [PROD_W-1:0] gx_wide;
    wire signed [PROD_W-1:0] gy_wide;

    assign gx_wide = {{GRAD_W{gx[GRAD_W-1]}}, gx};
    assign gy_wide = {{GRAD_W{gy[GRAD_W-1]}}, gy};

    always @* begin
        ix2  = gx_wide * gx_wide;
        iy2  = gy_wide * gy_wide;
        ixiy = gx_wide * gy_wide;
    end

endmodule