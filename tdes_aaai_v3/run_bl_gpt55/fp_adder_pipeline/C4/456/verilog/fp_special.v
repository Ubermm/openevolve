module fp_special (
    input  [31:0] a,
    input  [31:0] b,
    input         sign_a,
    input         sign_b_eff,
    input         is_zero_a,
    input         is_zero_b,
    input         is_inf_a,
    input         is_inf_b,
    input         is_nan_a,
    input         is_nan_b,
    output reg        special_valid,
    output reg [31:0] special_result
);

    localparam [31:0] CANONICAL_QNAN = 32'h7fc00000;

    always @* begin
        special_valid  = 1'b0;
        special_result = 32'h00000000;

        if (is_nan_a || is_nan_b) begin
            special_valid  = 1'b1;
            special_result = CANONICAL_QNAN;
        end else if (is_inf_a && is_inf_b) begin
            special_valid = 1'b1;
            if (sign_a != sign_b_eff) begin
                special_result = CANONICAL_QNAN;
            end else begin
                special_result = {sign_a, 8'hff, 23'h000000};
            end
        end else if (is_inf_a) begin
            special_valid  = 1'b1;
            special_result = {sign_a, 8'hff, 23'h000000};
        end else if (is_inf_b) begin
            special_valid  = 1'b1;
            special_result = {sign_b_eff, 8'hff, 23'h000000};
        end else if (is_zero_a && is_zero_b) begin
            special_valid = 1'b1;
            if (sign_a == sign_b_eff) begin
                special_result = {sign_a, 31'h00000000};
            end else begin
                special_result = 32'h00000000;
            end
        end else if (is_zero_a) begin
            special_valid  = 1'b1;
            special_result = {sign_b_eff, b[30:0]};
        end else if (is_zero_b) begin
            special_valid  = 1'b1;
            special_result = {sign_a, a[30:0]};
        end
    end

endmodule