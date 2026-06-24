module hpf_scaler #(
    parameter DATA_W = 20,
    parameter GAIN_W = 4
) (
    input  wire signed [63:0]              sum_in,
    output wire signed [DATA_W+GAIN_W-1:0] data_out
);

    // Arithmetic right shift by DATA_W to undo coefficient scaling.
    // sum_in is a 64-bit signed accumulator; after shift we truncate to output width.
    wire signed [63:0] shifted;
    assign shifted  = sum_in >>> DATA_W;
    assign data_out = shifted[DATA_W+GAIN_W-1:0];

endmodule