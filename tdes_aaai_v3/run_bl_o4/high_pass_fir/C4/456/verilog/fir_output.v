module fir_output #(
    parameter DATA_W = 20,
    parameter GAIN_W = 4
) (
    input  wire signed [63:0]                   sum_in,
    output wire signed [DATA_W+GAIN_W-1:0]      data_out
);

    // Remove fractional bits by arithmetic right shift, then truncate to output width
    localparam OUT_W = DATA_W + GAIN_W;
    wire signed [63:0] shifted;
    
    // Arithmetic shift to discard the lower DATA_W fractional bits
    assign shifted  = sum_in >>> DATA_W;
    // Truncate to OUT_W bits (keeps LSBs of shifted result, including sign)
    assign data_out = shifted[OUT_W-1:0];

endmodule