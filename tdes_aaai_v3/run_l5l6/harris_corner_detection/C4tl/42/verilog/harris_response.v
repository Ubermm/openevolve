`timescale 1ns/1ps

module harris_response #(
    parameter M_W        = 32,
    parameter RESP_W     = 32,
    parameter K_W        = 8,
    parameter K_FRAC     = 8,
    parameter RESP_SHIFT = 16
) (
    input  signed [M_W-1:0]    m_xx,
    input  signed [M_W-1:0]    m_yy,
    input  signed [M_W-1:0]    m_xy,
    input         [K_W-1:0]    k_param,
    output reg signed [RESP_W-1:0] response
);

    /*
     * Use explicit 128-bit signed intermediates.
     *
     * The Harris response contains products of tensor entries and trace^2.
     * With default M_W=32, the raw products can require more than 64 signed
     * bits in corner cases, and Verilog multiplication expressions may be
     * truncated if operands are not first widened.  Therefore all arithmetic
     * operands are promoted before multiplication.
     */

    reg signed [127:0] xx128;
    reg signed [127:0] yy128;
    reg signed [127:0] xy128;
    reg signed [127:0] k128;

    reg signed [127:0] trace128;

    reg signed [127:0] xx_yy_prod128;
    reg signed [127:0] xy_xy_prod128;
    reg signed [127:0] det128;

    reg signed [127:0] trace_sq128;
    reg signed [127:0] kterm_unscaled128;
    reg signed [127:0] kterm128;

    reg signed [127:0] resp_unscaled128;
    reg signed [127:0] resp_scaled128;

    reg signed [127:0] max_resp128;
    reg signed [127:0] min_resp128;

    always @* begin
        /*
         * Signed tensor terms are sign-extended by assignment.
         * k_param is unsigned fixed-point, so it is zero-extended.
         */
        xx128 = m_xx;
        yy128 = m_yy;
        xy128 = m_xy;
        k128  = k_param;

        /*
         * trace = m_xx + m_yy
         * det   = m_xx*m_yy - m_xy*m_xy
         */
        trace128 = xx128 + yy128;

        xx_yy_prod128 = xx128 * yy128;
        xy_xy_prod128 = xy128 * xy128;
        det128        = xx_yy_prod128 - xy_xy_prod128;

        /*
         * k term:
         * k_param is Q0.K_FRAC fixed-point.
         *
         * kterm = (trace^2 * k_param) >> K_FRAC
         */
        trace_sq128       = trace128 * trace128;
        kterm_unscaled128 = trace_sq128 * k128;
        kterm128          = kterm_unscaled128 >>> K_FRAC;

        /*
         * Response:
         * R = det - k*trace^2
         *
         * RESP_SHIFT scales the wide internal value down to the exported
         * response format.
         */
        resp_unscaled128 = det128 - kterm128;
        resp_scaled128   = resp_unscaled128 >>> RESP_SHIFT;

        /*
         * Signed saturation to RESP_W bits.
         */
        max_resp128 = (128'sd1 <<< (RESP_W-1)) - 128'sd1;
        min_resp128 = -(128'sd1 <<< (RESP_W-1));

        if (resp_scaled128 > max_resp128) begin
            response = {1'b0, {RESP_W-1{1'b1}}};
        end else if (resp_scaled128 < min_resp128) begin
            response = {1'b1, {RESP_W-1{1'b0}}};
        end else begin
            response = resp_scaled128[RESP_W-1:0];
        end
    end

endmodule