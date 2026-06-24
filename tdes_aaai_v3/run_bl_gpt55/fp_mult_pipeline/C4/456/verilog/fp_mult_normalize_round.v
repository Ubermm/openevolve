module fp_mult_normalize_round (
    input  [47:0] product,
    input  signed [10:0] exp_pre,
    output reg signed [10:0] exp_rounded,
    output reg [22:0] frac_rounded,
    output reg product_zero
);

    integer i;
    integer lead_pos;
    integer shift_left;

    reg [47:0] shifted_product;
    reg signed [10:0] exp_norm;

    reg [23:0] mant_norm;
    reg guard_bit;
    reg round_bit;
    reg sticky_bit;
    reg round_inc;
    reg [24:0] mant_rounded;

    always @* begin
        product_zero    = (product == 48'd0);
        exp_rounded     = 11'sd0;
        frac_rounded    = 23'd0;

        lead_pos        = -1;
        shift_left      = 0;
        shifted_product = 48'd0;
        exp_norm        = 11'sd0;

        mant_norm       = 24'd0;
        guard_bit       = 1'b0;
        round_bit       = 1'b0;
        sticky_bit      = 1'b0;
        round_inc       = 1'b0;
        mant_rounded    = 25'd0;

        if (!product_zero) begin
            if (product[47]) begin
                /*
                 * Product is in [2.0, 4.0). Normalize by shifting right one
                 * binary position and incrementing the exponent.
                 */
                exp_norm    = exp_pre + 11'sd1;
                mant_norm   = product[47:24];
                guard_bit   = product[23];
                round_bit   = product[22];
                sticky_bit  = |product[21:0];
            end else begin
                /*
                 * Product is below 2.0. Locate the leading one and left-shift
                 * so that it lands in bit 46, the normal hidden-bit position.
                 */
                for (i = 0; i < 48; i = i + 1) begin
                    if (product[i])
                        lead_pos = i;
                end

                shift_left      = 46 - lead_pos;
                shifted_product = product << shift_left;
                exp_norm        = exp_pre - shift_left[10:0];

                mant_norm       = shifted_product[46:23];
                guard_bit       = shifted_product[22];
                round_bit       = shifted_product[21];
                sticky_bit      = |shifted_product[20:0];
            end

            /*
             * Round to nearest, ties to even:
             * increment when guard is set and either the discarded portion is
             * greater than half or exactly half with an odd retained LSB.
             */
            round_inc    = guard_bit & (round_bit | sticky_bit | mant_norm[0]);
            mant_rounded = {1'b0, mant_norm} + {24'd0, round_inc};

            /*
             * Rounding can overflow 1.111... to 10.000..., requiring one more
             * exponent increment and a zero fraction field.
             */
            if (mant_rounded[24]) begin
                exp_rounded  = exp_norm + 11'sd1;
                frac_rounded = mant_rounded[23:1];
            end else begin
                exp_rounded  = exp_norm;
                frac_rounded = mant_rounded[22:0];
            end
        end
    end

endmodule