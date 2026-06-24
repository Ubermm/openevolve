module fp_mult_status (
    input  special_nan,
    input  special_inf,
    input  special_zero,
    input  product_zero,
    input  signed [10:0] exp_rounded,
    output overflow,
    output underflow
);

    wire suppress_checks;

    assign suppress_checks = special_nan | special_inf | special_zero | product_zero;

    assign overflow  = (~suppress_checks) && (exp_rounded >= 11'sd255);
    assign underflow = (~suppress_checks) && (exp_rounded <= 11'sd0);

endmodule