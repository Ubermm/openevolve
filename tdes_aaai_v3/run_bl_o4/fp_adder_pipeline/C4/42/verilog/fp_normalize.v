module fp_normalize(
    input  wire [25:0] raw_sum,   // aligned sum with possible carry
    input  wire [7:0]  exp_in,    // input exponent (biased)
    output reg  [7:0]  exp_out,
    output reg  [25:0] mant_out
);

    // Temporary signals for normalization
    reg [7:0]  exp_tmp;
    reg [25:0] mant_tmp;
    reg [4:0]  shift_amt;
    reg        found;
    integer    i;

    always @* begin
        // Default pass-through
        exp_tmp  = exp_in;
        mant_tmp = raw_sum;

        // Case 1: zero result
        if (raw_sum == 26'd0) begin
            exp_tmp  = 8'd0;
            mant_tmp = 26'd0;
        end
        // Case 2: overflow from addition: MSB at bit 25
        else if (raw_sum[25]) begin
            exp_tmp  = exp_in + 1;
            mant_tmp = raw_sum >> 1;
        end
        // Case 3: need to normalize by shifting left
        else begin
            found     = 1'b0;
            shift_amt = 5'd0;
            // find first '1' from MSB side in bits [24:0]
            for (i = 24; i >= 0; i = i - 1) begin
                if (!found && raw_sum[i]) begin
                    shift_amt = 24 - i;
                    found     = 1'b1;
                end
            end
            exp_tmp  = exp_in - shift_amt;
            mant_tmp = raw_sum << shift_amt;
        end

        // Drive outputs
        exp_out  = exp_tmp;
        mant_out = mant_tmp;
    end

endmodule