module output_stage #(
    parameter ACC_W  = 0,
    parameter OUT_W  = 0,
    parameter SHIFT  = 0
) (
    input  signed [ACC_W-1:0] sum_in,
    output signed [OUT_W-1:0] data_out
);
    // Arithmetic right shift by SHIFT bits
    wire signed [ACC_W-1:0] shifted = sum_in >>> SHIFT;
    // Truncate by taking the top OUT_W bits of the shifted result
    assign data_out = shifted[ACC_W-1 : ACC_W-OUT_W];
endmodule