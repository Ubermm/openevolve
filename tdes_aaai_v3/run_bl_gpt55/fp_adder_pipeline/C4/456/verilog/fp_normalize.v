module fp_normalize (
    input         sign_in,
    input  [7:0] exp_in,
    input  [28:0] mag_in,
    output reg        sign_out,
    output reg [8:0]  exp_out,
    output reg [27:0] sig_out
);

    function [4:0] leading_zeros_28;
        input [27:0] value;
        integer i;
        reg found;
        begin
            leading_zeros_28 = 5'd28;
            found = 1'b0;
            for (i = 27; i >= 0; i = i - 1) begin
                if (!found && value[i]) begin
                    leading_zeros_28 = 27 - i;
                    found = 1'b1;
                end
            end
        end
    endfunction

    reg [4:0] lz;
    reg [4:0] shamt;

    always @* begin
        sign_out = sign_in;
        exp_out  = {1'b0, exp_in};
        sig_out  = mag_in[27:0];

        if (mag_in == 29'b0) begin
            sign_out = 1'b0;
            exp_out  = 9'b0;
            sig_out  = 28'b0;
        end else if (mag_in[28]) begin
            sign_out = sign_in;
            exp_out  = {1'b0, exp_in} + 9'd1;
            sig_out  = {mag_in[28:2], (mag_in[1] | mag_in[0])};
        end else begin
            lz = leading_zeros_28(mag_in[27:0]);

            if (lz == 5'd0) begin
                sign_out = sign_in;
                exp_out  = {1'b0, exp_in};
                sig_out  = mag_in[27:0];
            end else begin
                if (exp_in == 8'd0) begin
                    shamt = 5'd0;
                    exp_out = 9'd0;
                end else if ({4'b0, exp_in} > {4'b0, lz}) begin
                    shamt = lz;
                    exp_out = {1'b0, exp_in} - {4'b0, lz};
                end else begin
                    shamt = exp_in[4:0] - 5'd1;
                    exp_out = 9'd0;
                end

                sign_out = sign_in;
                sig_out  = mag_in[27:0] << shamt;
            end
        end
    end

endmodule