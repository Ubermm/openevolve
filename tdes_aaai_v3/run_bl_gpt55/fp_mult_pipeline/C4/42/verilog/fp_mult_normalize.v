`timescale 1ns/1ps

module fp_mult_normalize (
    input  [47:0] product,
    input  signed [10:0] exp_in,
    output reg [23:0] mant_pre,
    output reg guard_bit,
    output reg round_bit,
    output reg sticky_bit,
    output reg signed [10:0] exp_norm
);

    reg [47:0] norm_product;
    reg [5:0]  lshift;
    integer i;
    reg found;

    always @* begin
        mant_pre     = 24'b0;
        guard_bit    = 1'b0;
        round_bit    = 1'b0;
        sticky_bit   = 1'b0;
        exp_norm     = exp_in;
        norm_product = product;
        lshift       = 6'd0;
        found        = 1'b0;

        if (product == 48'b0) begin
            mant_pre     = 24'b0;
            guard_bit    = 1'b0;
            round_bit    = 1'b0;
            sticky_bit   = 1'b0;
            exp_norm     = exp_in;
        end else if (product[47]) begin
            /*
             * Product is in [2,4).  Shift right by one significand bit:
             * keep product[47:24], and increment the exponent.
             */
            mant_pre   = product[47:24];
            guard_bit  = product[23];
            round_bit  = product[22];
            sticky_bit = |product[21:0];
            exp_norm   = exp_in + 11'sd1;
        end else begin
            /*
             * Product is below 2.  For normal products product[46] is set and
             * no left shift is needed.  If an input significand was subnormal,
             * leading zeros may be present; shift left until bit 46 is the
             * leading one and decrement the exponent by the shift amount.
             */
            for (i = 46; i >= 0; i = i - 1) begin
                if (!found && product[i]) begin
                    lshift = 46 - i;
                    found  = 1'b1;
                end
            end

            norm_product = product << lshift;

            mant_pre   = norm_product[46:23];
            guard_bit  = norm_product[22];
            round_bit  = norm_product[21];
            sticky_bit = |norm_product[20:0];
            exp_norm   = exp_in - $signed({5'b0, lshift});
        end
    end

endmodule