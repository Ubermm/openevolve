module fp_addsub_sig (
    input sign_large,
    input sign_small,
    input [8:0] exp_large,
    input [26:0] mant_large,
    input [26:0] mant_small,
    output reg sign_out,
    output reg [8:0] exp_out,
    output reg [27:0] mant_sum
);

    reg [27:0] add_result;
    reg [27:0] sub_result;

    always @* begin
        add_result = {1'b0, mant_large} + {1'b0, mant_small};
        sub_result = {1'b0, mant_large} - {1'b0, mant_small};

        exp_out = exp_large;

        if (sign_large == sign_small) begin
            mant_sum = add_result;
            sign_out = sign_large;
        end else begin
            mant_sum = sub_result;
            sign_out = sign_large;
        end

        if (mant_sum == 28'd0) begin
            sign_out = 1'b0;
            exp_out = 9'd0;
        end
    end

endmodule