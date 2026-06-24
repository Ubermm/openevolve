module fp_pack(
    input        sign,
    input  signed [9:0] exp_unbiased,
    input  [23:0] mantissa,
    input        is_zero_a,
    input        is_inf_a,
    input        is_nan_a,
    input        is_zero_b,
    input        is_inf_b,
    input        is_nan_b,
    output [31:0] result
);
    // IEEE-754 parameters
    localparam integer BIAS    = 127;
    localparam integer E_MAX   = 127;   // max normal exponent
    localparam integer E_MIN_N = -126;  // min normal exponent

    // Detect operand special cases and zero mantissa
    wire special_nan   = is_nan_a
                       | is_nan_b
                       | (is_inf_a & is_zero_b)
                       | (is_zero_a & is_inf_b);
    wire special_inf   = ~special_nan & (is_inf_a | is_inf_b);
    wire mant_zero     = (mantissa == 24'd0);
    wire special_zero  = ~special_nan & ~special_inf
                       & (is_zero_a | is_zero_b | mant_zero);

    // Signed exponent for comparisons
    wire signed [10:0] exp_s = exp_unbiased;

    // Overflow and subnormal detection (only for finite non-zero)
    wire overflow = ~special_nan & ~special_inf & ~special_zero
                  & (exp_s > E_MAX);
    wire subnormal = ~special_nan & ~special_inf & ~special_zero
                   & ~overflow
                   & (exp_s < E_MIN_N);

    // Prepare subnormal shift
    wire signed [10:0] diff = E_MIN_N - exp_s; // >0 if subnormal
    wire [4:0] shift_amt = (diff > 11'd23) ? 5'd23 : diff[4:0];
    wire [23:0] mant_sub = mantissa >> shift_amt;

    // QNaN payload (quiet NaN)
    localparam [22:0] MANT_QNAN = 23'b10000000000000000000000;

    // Exponent field selection
    wire [7:0] exp_field = special_nan   ? 8'hFF :
                           special_inf   ? 8'hFF :
                           special_zero  ? 8'h00 :
                           overflow      ? 8'hFF :
                           subnormal     ? 8'h00 :
                                           (exp_s + BIAS);

    // Fraction field selection
    wire [22:0] frac_field = special_nan   ? MANT_QNAN :
                             special_inf   ? 23'd0 :
                             special_zero  ? 23'd0 :
                             overflow      ? 23'd0 :
                             subnormal     ? mant_sub[22:0] :
                                             mantissa[22:0];

    // Sign bit: NaN has canonical +0
    wire sign_field = special_nan ? 1'b0 : sign;

    // Assemble result
    assign result = { sign_field, exp_field, frac_field };
endmodule