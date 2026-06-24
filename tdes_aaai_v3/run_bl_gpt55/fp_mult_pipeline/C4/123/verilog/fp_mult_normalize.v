module fp_mult_normalize (
    input  [47:0] product,
    input  signed [11:0] exp_in,
    output reg [23:0] sig,
    output reg signed [11:0] exp_out,
    output reg guard_bit,
    output reg round_bit,
    output reg sticky_bit
);

    integer i;
    integer j;
    integer lead_pos;
    reg found;

    always @* begin
        sig        = 24'b0;
        exp_out    = 12'sd0;
        guard_bit  = 1'b0;
        round_bit  = 1'b0;
        sticky_bit = 1'b0;
        lead_pos   = 0;
        found      = 1'b0;

        if (product != 48'b0) begin
            for (i = 47; i >= 0; i = i - 1) begin
                if (!found && product[i]) begin
                    lead_pos = i;
                    found = 1'b1;
                end
            end

            exp_out = exp_in + (lead_pos - 46);

            for (j = 0; j < 24; j = j + 1) begin
                if (lead_pos >= j)
                    sig[23-j] = product[lead_pos-j];
                else
                    sig[23-j] = 1'b0;
            end

            if (lead_pos >= 24)
                guard_bit = product[lead_pos-24];
            else
                guard_bit = 1'b0;

            if (lead_pos >= 25)
                round_bit = product[lead_pos-25];
            else
                round_bit = 1'b0;

            sticky_bit = 1'b0;
            if (lead_pos >= 26) begin
                for (i = 0; i <= lead_pos - 26; i = i + 1) begin
                    sticky_bit = sticky_bit | product[i];
                end
            end
        end
    end

endmodule