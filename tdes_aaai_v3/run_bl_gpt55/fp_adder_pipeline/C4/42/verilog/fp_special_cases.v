module fp_special_cases (
    input sign_a,
    input sign_b,
    input [7:0] exp_a,
    input [7:0] exp_b,
    input [22:0] frac_a,
    input [22:0] frac_b,
    input is_zero_a,
    input is_zero_b,
    input is_inf_a,
    input is_inf_b,
    input is_nan_a,
    input is_nan_b,
    output reg special_valid,
    output reg [31:0] special_result
);

    localparam [31:0] CANONICAL_QNAN = 32'h7fc00000;

    always @(*) begin
        special_valid  = 1'b0;
        special_result = 32'b0;

        if (is_nan_a || is_nan_b) begin
            special_valid  = 1'b1;
            special_result = CANONICAL_QNAN;
        end else if (is_inf_a && is_inf_b) begin
            special_valid = 1'b1;
            if (sign_a != sign_b) begin
                special_result = CANONICAL_QNAN;
            end else begin
                special_result = {sign_a, 8'hff, 23'b0};
            end
        end else if (is_inf_a) begin
            special_valid  = 1'b1;
            special_result = {sign_a, 8'hff, 23'b0};
        end else if (is_inf_b) begin
            special_valid  = 1'b1;
            special_result = {sign_b, 8'hff, 23'b0};
        end else if (is_zero_a && is_zero_b) begin
            special_valid  = 1'b1;
            special_result = {sign_a & sign_b, 8'b0, 23'b0};
        end else if (is_zero_a) begin
            special_valid  = 1'b1;
            special_result = {sign_b, exp_b, frac_b};
        end else if (is_zero_b) begin
            special_valid  = 1'b1;
            special_result = {sign_a, exp_a, frac_a};
        end
    end

endmodule