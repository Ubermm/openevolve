module fp_align (
    input         sign_a,
    input         sign_b_eff,
    input  [7:0]  exp_a_eff,
    input  [7:0]  exp_b_eff,
    input  [23:0] sig_a,
    input  [23:0] sig_b,
    output reg        sign_large,
    output reg        sign_small,
    output reg [7:0]  exp_large,
    output reg [27:0] sig_large,
    output reg [27:0] sig_small
);

    reg        a_is_larger;
    reg [7:0]  exp_diff;
    reg [27:0] large_ext;
    reg [27:0] small_ext;

    function [27:0] shift_right_sticky;
        input [27:0] value;
        input [7:0]  shamt;
        reg   [27:0] shifted;
        reg   [27:0] mask;
        reg          sticky;
        begin
            if (shamt == 8'd0) begin
                shift_right_sticky = value;
            end else if (shamt >= 8'd28) begin
                shift_right_sticky = (|value) ? 28'd1 : 28'd0;
            end else begin
                shifted = value >> shamt;
                mask    = (28'd1 << shamt) - 28'd1;
                sticky  = |(value & mask);
                shifted[0] = shifted[0] | sticky;
                shift_right_sticky = shifted;
            end
        end
    endfunction

    always @* begin
        if (exp_a_eff > exp_b_eff) begin
            a_is_larger = 1'b1;
        end else if (exp_a_eff < exp_b_eff) begin
            a_is_larger = 1'b0;
        end else begin
            a_is_larger = (sig_a >= sig_b);
        end

        if (a_is_larger) begin
            sign_large = sign_a;
            sign_small = sign_b_eff;
            exp_large  = exp_a_eff;
            exp_diff   = exp_a_eff - exp_b_eff;

            large_ext  = {1'b0, sig_a, 3'b000};
            small_ext  = {1'b0, sig_b, 3'b000};
        end else begin
            sign_large = sign_b_eff;
            sign_small = sign_a;
            exp_large  = exp_b_eff;
            exp_diff   = exp_b_eff - exp_a_eff;

            large_ext  = {1'b0, sig_b, 3'b000};
            small_ext  = {1'b0, sig_a, 3'b000};
        end

        sig_large = large_ext;
        sig_small = shift_right_sticky(small_ext, exp_diff);
    end

endmodule