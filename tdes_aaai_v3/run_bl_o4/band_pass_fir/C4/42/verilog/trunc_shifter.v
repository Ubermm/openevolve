module trunc_shifter #(
    parameter IN_W   = 64,
    parameter OUT_W  = 24,
    parameter SHIFT  = 20
) (
    input  wire signed [IN_W-1:0] in_data,
    output wire signed [OUT_W-1:0] out_data
);
    // Arithmetic right-shift by SHIFT, then truncate to OUT_W bits
    wire signed [IN_W-1:0] shifted;
    assign shifted  = in_data >>> SHIFT;
    assign out_data = shifted[OUT_W-1:0];
endmodule