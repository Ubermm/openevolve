module fp_addsub_significands (
    input         sign_large,
    input         sign_small,
    input  [7:0]  exp_large,
    input  [27:0] sig_large,
    input  [27:0] sig_small,
    output reg        result_sign,
    output reg [7:0]  result_exp,
    output reg [28:0] result_mag
);

    reg [28:0] add_mag;
    reg [28:0] sub_mag;

    always @* begin
        result_exp = exp_large;

        if (sign_large == sign_small) begin
            add_mag     = {1'b0, sig_large} + {1'b0, sig_small};
            result_mag  = add_mag;
            result_sign = sign_large;
        end else begin
            if (sig_large >= sig_small) begin
                sub_mag     = {1'b0, sig_large} - {1'b0, sig_small};
                result_mag  = sub_mag;
                result_sign = (sub_mag == 29'd0) ? 1'b0 : sign_large;
            end else begin
                sub_mag     = {1'b0, sig_small} - {1'b0, sig_large};
                result_mag  = sub_mag;
                result_sign = (sub_mag == 29'd0) ? 1'b0 : sign_small;
            end
        end
    end

endmodule