module fp_normalize (
    input sign_in,
    input [8:0] exp_in,
    input [27:0] mant_in,
    output reg sign_out,
    output reg [8:0] exp_out,
    output reg [26:0] mant_out,
    output reg is_zero
);

    integer i;
    reg found;
    reg [5:0] shift_amt;
    reg [5:0] actual_shift;

    always @* begin
        sign_out     = sign_in;
        exp_out      = exp_in;
        mant_out     = mant_in[26:0];
        is_zero      = 1'b0;
        shift_amt    = 6'd0;
        actual_shift = 6'd0;
        found        = 1'b0;

        if (mant_in == 28'd0) begin
            sign_out = 1'b0;
            exp_out  = 9'd0;
            mant_out = 27'd0;
            is_zero  = 1'b1;
        end else if (mant_in[27]) begin
            sign_out = sign_in;
            exp_out  = exp_in + 9'd1;

            /*
             * Right normalization after significand addition carry-out.
             * mant_in[0] is sticky, so when shifting right, jam the dropped
             * bit into the outgoing sticky bit.
             */
            mant_out = {mant_in[27:2], (mant_in[1] | mant_in[0])};
            is_zero  = 1'b0;
        end else begin
            /*
             * Left normalization after cancellation.
             * Find the leading one in mant_in[26:0] and shift it to bit 26
             * when the exponent allows.  If the shift would drive the
             * exponent below zero, stop at exponent zero for subnormal output.
             */
            for (i = 26; i >= 0; i = i - 1) begin
                if (!found && mant_in[i]) begin
                    shift_amt = 26 - i;
                    found     = 1'b1;
                end
            end

            if (exp_in > shift_amt) begin
                actual_shift = shift_amt;
                exp_out      = exp_in - shift_amt;
            end else if (exp_in != 9'd0) begin
                actual_shift = exp_in[5:0] - 6'd1;
                exp_out      = 9'd0;
            end else begin
                actual_shift = 6'd0;
                exp_out      = 9'd0;
            end

            mant_out = (mant_in[26:0] << actual_shift);
            sign_out = sign_in;
            is_zero  = 1'b0;
        end
    end

endmodule