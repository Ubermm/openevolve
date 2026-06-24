`timescale 1ns/1ps

module fp_significand_addsub (
    input        sign_large,
    input        sign_small,
    input  [26:0] sig_large_ext,
    input  [26:0] sig_small_ext,
    output       result_sign,
    output [27:0] sig_sum,
    output       is_zero
);

    reg        result_sign_r;
    reg [27:0] sig_sum_r;

    always @* begin
        if (sign_large == sign_small) begin
            sig_sum_r     = {1'b0, sig_large_ext} + {1'b0, sig_small_ext};
            result_sign_r = sign_large;
        end else begin
            if (sig_large_ext >= sig_small_ext) begin
                sig_sum_r     = {1'b0, sig_large_ext} - {1'b0, sig_small_ext};
                result_sign_r = sign_large;
            end else begin
                sig_sum_r     = {1'b0, sig_small_ext} - {1'b0, sig_large_ext};
                result_sign_r = sign_small;
            end
        end

        if (sig_sum_r == 28'd0) begin
            result_sign_r = 1'b0;
        end
    end

    assign sig_sum     = sig_sum_r;
    assign is_zero     = (sig_sum_r == 28'd0);
    assign result_sign = result_sign_r;

endmodule