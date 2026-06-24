module fp_normalize (
    input  [27:0] man_in,
    input  [7:0]  exp_in,
    input         sign_in,
    input         isZero_in,
    output reg [27:0] man_out,
    output reg [7:0]  exp_out,
    output reg        sign_out,
    output reg        isZero_out
);

    // Intermediate signals
    reg [8:0]  exp_tmp;
    reg [4:0]  shift_amt;
    reg        found;
    integer    idx;

    always @* begin
        // default propagate sign
        sign_out = sign_in;

        // Treat zero if input mantissa is zero (ignore isZero_in to avoid spurious zero)
        if (man_in == 28'b0) begin
            man_out    = 28'b0;
            exp_out    = 8'b0;
            isZero_out = 1'b1;
        end else begin
            isZero_out = 1'b0;
            exp_tmp    = {1'b0, exp_in};

            // Overflow detection: bit27=1 => needs right shift by 1
            if (man_in[27]) begin
                shift_amt  = 5'd1;
                exp_tmp    = exp_tmp + 9'd1;
                man_out    = man_in >> 1;
            end else begin
                // count leading zeros on bits [26:0]
                found      = 1'b0;
                shift_amt  = 5'd0;
                for (idx = 26; idx >= 0; idx = idx - 1) begin
                    if (!found && man_in[idx]) begin
                        found     = 1'b1;
                        shift_amt = 27 - idx;
                    end
                end
                // shift left to normalize MSB to bit27
                man_out = man_in << shift_amt;
                // adjust exponent down by shift_amt
                exp_tmp = exp_tmp - shift_amt;
            end

            // underflow: if exponent went negative
            if (exp_tmp[8]) begin
                // result underflows to zero
                man_out    = 28'b0;
                exp_out    = 8'b0;
                isZero_out = 1'b1;
            end
            // overflow to infinity
            else if (exp_tmp >= 9'h0FF) begin
                man_out    = 28'b0;
                exp_out    = 8'hFF;
                isZero_out = 1'b0;
            end
            // normal case
            else begin
                exp_out = exp_tmp[7:0];
            end
        end
    end

endmodule