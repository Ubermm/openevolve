`timescale 1ns/1ps

module fpm_mul_normalize #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23
)(
    input  sign_a,
    input  sign_b,
    input  [MANT_WIDTH:0] sig_a,
    input  [MANT_WIDTH:0] sig_b,
    input  signed [EXP_WIDTH+4:0] exp_unbiased_a,
    input  signed [EXP_WIDTH+4:0] exp_unbiased_b,
    output reg result_sign,
    output reg signed [EXP_WIDTH+4:0] result_exp_unbiased,
    output reg [MANT_WIDTH:0] result_sig,
    output reg guard_bit,
    output reg round_bit,
    output reg sticky_bit,
    output reg zero_product
);

    localparam integer SIG_WIDTH  = MANT_WIDTH + 1;
    localparam integer PROD_WIDTH = 2 * SIG_WIDTH;
    localparam integer EXP_CALC_WIDTH = EXP_WIDTH + 5;

    reg [PROD_WIDTH-1:0] product_full;
    reg signed [EXP_WIDTH+4:0] exp_sum;
    reg signed [EXP_WIDTH+4:0] exp_adjust;

    integer i;
    integer leading_pos;
    integer bit_index;
    integer sticky_limit;
    reg found_leading_one;

    always @* begin
        result_sign          = sign_a ^ sign_b;
        result_exp_unbiased  = {EXP_CALC_WIDTH{1'b0}};
        result_sig           = {SIG_WIDTH{1'b0}};
        guard_bit            = 1'b0;
        round_bit            = 1'b0;
        sticky_bit           = 1'b0;
        zero_product         = 1'b0;

        product_full         = {PROD_WIDTH{1'b0}};
        exp_sum              = exp_unbiased_a + exp_unbiased_b;
        exp_adjust           = {EXP_CALC_WIDTH{1'b0}};
        leading_pos          = 0;
        bit_index            = 0;
        sticky_limit         = 0;
        found_leading_one    = 1'b0;

        product_full = {{SIG_WIDTH{1'b0}}, sig_a} * {{SIG_WIDTH{1'b0}}, sig_b};

        if (product_full == {PROD_WIDTH{1'b0}}) begin
            zero_product = 1'b1;
        end else begin
            for (i = PROD_WIDTH-1; i >= 0; i = i - 1) begin
                if (!found_leading_one && product_full[i]) begin
                    leading_pos       = i;
                    found_leading_one = 1'b1;
                end
            end

            exp_adjust = leading_pos - (2 * MANT_WIDTH);
            result_exp_unbiased = exp_sum + exp_adjust;

            for (i = 0; i < SIG_WIDTH; i = i + 1) begin
                bit_index = leading_pos - i;
                if ((bit_index >= 0) && (bit_index < PROD_WIDTH)) begin
                    result_sig[MANT_WIDTH-i] = product_full[bit_index];
                end
            end

            bit_index = leading_pos - SIG_WIDTH;
            if ((bit_index >= 0) && (bit_index < PROD_WIDTH)) begin
                guard_bit = product_full[bit_index];
            end

            bit_index = leading_pos - SIG_WIDTH - 1;
            if ((bit_index >= 0) && (bit_index < PROD_WIDTH)) begin
                round_bit = product_full[bit_index];
            end

            sticky_limit = leading_pos - SIG_WIDTH - 2;
            if (sticky_limit >= 0) begin
                for (i = 0; i < PROD_WIDTH; i = i + 1) begin
                    if (i <= sticky_limit) begin
                        sticky_bit = sticky_bit | product_full[i];
                    end
                end
            end
        end
    end

endmodule