module fp_mult_pack (
    input  sign,
    input  special_nan,
    input  special_inf,
    input  special_zero,
    input  overflow,
    input  underflow,
    input  signed [10:0] exp_rounded,
    input  [22:0] frac_rounded,
    output reg [31:0] result
);

    localparam [31:0] CANONICAL_NAN = 32'h7FC00000;
    localparam [7:0]  EXP_INF_NAN   = 8'hFF;
    localparam [22:0] FRAC_ZERO     = 23'h000000;

    always @* begin
        if (special_nan) begin
            result = CANONICAL_NAN;
        end else if (special_inf) begin
            result = {sign, EXP_INF_NAN, FRAC_ZERO};
        end else if (special_zero) begin
            result = {sign, 31'h00000000};
        end else if (overflow) begin
            result = {sign, EXP_INF_NAN, FRAC_ZERO};
        end else if (underflow) begin
            result = {sign, 31'h00000000};
        end else begin
            result = {sign, exp_rounded[7:0], frac_rounded};
        end
    end

endmodule