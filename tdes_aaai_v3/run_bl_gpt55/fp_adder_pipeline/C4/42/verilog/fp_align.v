module fp_align (
    input sign_a,
    input sign_b,
    input [7:0] exp_a,
    input [7:0] exp_b,
    input [23:0] sig_a,
    input [23:0] sig_b,
    output reg sign_large,
    output reg sign_small,
    output reg [8:0] exp_large,
    output reg [26:0] mant_large,
    output reg [26:0] mant_small
);

    reg        a_is_large;
    reg [8:0]  exp_a_eff;
    reg [8:0]  exp_b_eff;
    reg [8:0]  exp_diff;
    reg [23:0] sig_large;
    reg [23:0] sig_small;

    function [26:0] shift_right_sticky;
        input [26:0] value;
        input [8:0]  shamt;
        reg [26:0] shifted;
        reg sticky;
        begin
            if (shamt == 9'd0) begin
                shift_right_sticky = value;
            end else if (shamt >= 9'd27) begin
                shift_right_sticky = {26'b0, |value};
            end else begin
                shifted = value >> shamt;
                sticky  = |(value << (9'd27 - shamt));
                shift_right_sticky = shifted;
                shift_right_sticky[0] = shifted[0] | sticky;
            end
        end
    endfunction

    always @(*) begin
        exp_a_eff = (exp_a == 8'd0) ? 9'd1 : {1'b0, exp_a};
        exp_b_eff = (exp_b == 8'd0) ? 9'd1 : {1'b0, exp_b};

        if (exp_a_eff > exp_b_eff) begin
            a_is_large = 1'b1;
        end else if (exp_a_eff < exp_b_eff) begin
            a_is_large = 1'b0;
        end else begin
            a_is_large = (sig_a >= sig_b);
        end

        if (a_is_large) begin
            sign_large = sign_a;
            sign_small = sign_b;
            exp_large  = exp_a_eff;
            exp_diff   = exp_a_eff - exp_b_eff;
            sig_large  = sig_a;
            sig_small  = sig_b;
        end else begin
            sign_large = sign_b;
            sign_small = sign_a;
            exp_large  = exp_b_eff;
            exp_diff   = exp_b_eff - exp_a_eff;
            sig_large  = sig_b;
            sig_small  = sig_a;
        end

        mant_large = {sig_large, 3'b000};
        mant_small = shift_right_sticky({sig_small, 3'b000}, exp_diff);
    end

endmodule