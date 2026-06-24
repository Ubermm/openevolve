module fp_mult_round (
    input  [23:0] sig,
    input  signed [11:0] exp_in,
    input         guard_bit,
    input         round_bit,
    input         sticky_bit,
    output reg [23:0] mant_out,
    output reg [7:0]  exp_out,
    output reg        overflow,
    output reg        underflow
);

    reg        round_inc;
    reg [24:0] rounded_sig;
    reg signed [12:0] corrected_exp;

    always @* begin
        round_inc = guard_bit & (round_bit | sticky_bit | sig[0]);

        rounded_sig   = {1'b0, sig} + {24'b0, round_inc};
        corrected_exp = {exp_in[11], exp_in};

        if (rounded_sig[24]) begin
            mant_out      = rounded_sig[24:1];
            corrected_exp = corrected_exp + 13'sd1;
        end else begin
            mant_out = rounded_sig[23:0];
        end

        overflow  = (corrected_exp >= 13'sd255);
        underflow = (corrected_exp <= 13'sd0);

        if (overflow) begin
            exp_out  = 8'hFF;
            mant_out = 24'h800000;
        end else if (underflow) begin
            exp_out  = 8'h00;
            mant_out = 24'h000000;
        end else begin
            exp_out = corrected_exp[7:0];
        end
    end

endmodule