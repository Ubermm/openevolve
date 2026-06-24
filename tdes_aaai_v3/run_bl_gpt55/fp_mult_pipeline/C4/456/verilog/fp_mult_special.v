module fp_mult_special (
    input  sign_in,
    input  zero_a,
    input  zero_b,
    input  inf_a,
    input  inf_b,
    input  nan_a,
    input  nan_b,
    output special_nan,
    output special_inf,
    output special_zero,
    output sign_out
);

    wire invalid_zero_times_inf;

    assign invalid_zero_times_inf = (zero_a & inf_b) | (zero_b & inf_a);

    assign special_nan  = nan_a | nan_b | invalid_zero_times_inf;
    assign special_inf  = ~special_nan & (inf_a | inf_b);
    assign special_zero = ~special_nan & ~special_inf & (zero_a | zero_b);

    assign sign_out = sign_in;

endmodule