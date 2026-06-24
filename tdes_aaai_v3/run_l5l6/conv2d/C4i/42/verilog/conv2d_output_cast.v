`timescale 1ns/1ps

module conv2d_output_cast #(
    parameter ACC_W = 32,
    parameter OUT_W = 12
) (
    input      signed [ACC_W-1:0] accum,
    output reg        [OUT_W-1:0] pixel_out
);

    integer i;
    reg high_overflow;

    always @* begin
        high_overflow = 1'b0;

        /*
         * For a non-negative signed accumulator, any set bit above OUT_W-1
         * means the value is larger than the maximum unsigned OUT_W value:
         *
         *   max = 2^OUT_W - 1
         *
         * Negative values are handled separately using the sign bit.
         */
        for (i = OUT_W; i < ACC_W; i = i + 1) begin
            high_overflow = high_overflow | accum[i];
        end

        if (accum[ACC_W-1]) begin
            pixel_out = {OUT_W{1'b0}};
        end else if (high_overflow) begin
            pixel_out = {OUT_W{1'b1}};
        end else begin
            pixel_out = {OUT_W{1'b0}};

            /*
             * Copy the representable low bits.  In the normal design
             * ACC_W >= OUT_W, so this copies OUT_W bits.  The loop is
             * written defensively so the module also elaborates correctly
             * if OUT_W is larger than ACC_W.
             */
            for (i = 0; i < OUT_W; i = i + 1) begin
                if (i < ACC_W) begin
                    pixel_out[i] = accum[i];
                end
            end
        end
    end

endmodule