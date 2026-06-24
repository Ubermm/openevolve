module fp_round_pack (
    input sign_in,
    input [8:0] exp_in,
    input [26:0] mant_in,
    input is_zero,
    input special_valid,
    input [31:0] special_result,
    output reg [31:0] result
);

    reg [23:0] sig_main;
    reg [24:0] sig_round_ext;
    reg [24:0] sig_after_carry;
    reg [8:0]  exp_work;
    reg        round_inc;
    reg [7:0]  exp_out;
    reg [22:0] frac_out;

    always @* begin
        result          = 32'b0;
        sig_main        = 24'b0;
        sig_round_ext   = 25'b0;
        sig_after_carry = 25'b0;
        exp_work        = 9'b0;
        round_inc       = 1'b0;
        exp_out         = 8'b0;
        frac_out        = 23'b0;

        if (special_valid) begin
            result = special_result;
        end else if (is_zero || (mant_in == 27'b0)) begin
            result = {sign_in, 31'b0};
        end else begin
            /*
             * mant_in format from normalization:
             *   mant_in[26:3] : retained significand bits
             *                   bit 26 is the hidden bit for normal numbers
             *   mant_in[2]    : guard bit
             *   mant_in[1]    : round bit
             *   mant_in[0]    : sticky bit
             *
             * Round-to-nearest-even:
             *   increment when guard is set and either any following bit is set
             *   or the retained LSB is one.
             */
            sig_main  = mant_in[26:3];
            round_inc = mant_in[2] & (mant_in[1] | mant_in[0] | mant_in[3]);

            sig_round_ext = {1'b0, sig_main} + {24'b0, round_inc};
            exp_work      = exp_in;

            if (exp_in == 9'd0) begin
                /*
                 * Subnormal input/result.  If rounding promotes the significand
                 * into the hidden-bit position, emit the minimum normal value.
                 */
                if (sig_round_ext[23]) begin
                    exp_out  = 8'd1;
                    frac_out = sig_round_ext[22:0];
                end else begin
                    exp_out  = 8'd0;
                    frac_out = sig_round_ext[22:0];
                end

                result = {sign_in, exp_out, frac_out};
            end else begin
                /*
                 * Normal result.  A carry out of the 24-bit significand after
                 * rounding requires a right renormalization and exponent bump.
                 */
                if (sig_round_ext[24]) begin
                    sig_after_carry = {1'b0, sig_round_ext[24:1]};
                    exp_work        = exp_in + 9'd1;
                end else begin
                    sig_after_carry = sig_round_ext;
                    exp_work        = exp_in;
                end

                /*
                 * IEEE-754 single-precision overflow:
                 * exponent field 255 is reserved for Inf/NaN, so finite rounded
                 * results with exponent >= 255 become signed infinity.
                 */
                if (exp_work >= 9'd255) begin
                    result = {sign_in, 8'hff, 23'b0};
                end else begin
                    exp_out  = exp_work[7:0];
                    frac_out = sig_after_carry[22:0];
                    result   = {sign_in, exp_out, frac_out};
                end
            end
        end
    end

endmodule