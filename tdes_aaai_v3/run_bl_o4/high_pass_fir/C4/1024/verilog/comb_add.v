module comb_add #(
    parameter integer ACC_W  = 32,
    parameter integer MULT_W = 32
) (
    input  wire signed [ACC_W-1:0] sum_in,
    input  wire signed [MULT_W-1:0] mult_in,
    output wire signed [ACC_W-1:0] sum_out
);

    // Extend or truncate mult_in to match accumulator width
    wire signed [ACC_W-1:0] mult_ext;
    generate
        if (ACC_W > MULT_W) begin : GEN_SEXT
            // Sign-extend mult_in to ACC_W bits
            assign mult_ext = {{(ACC_W-MULT_W){mult_in[MULT_W-1]}}, mult_in};
        end else if (ACC_W < MULT_W) begin : GEN_TRUNC
            // Truncate mult_in to ACC_W bits, keeping its sign bit
            // Take the top ACC_W bits: from MULT_W-1 down to MULT_W-ACC_W
            assign mult_ext = mult_in[MULT_W-1 : MULT_W-ACC_W];
        end else begin : GEN_PASS
            // Same width -> direct pass
            assign mult_ext = mult_in;
        end
    endgenerate

    // Combinational addition
    assign sum_out = sum_in + mult_ext;

endmodule