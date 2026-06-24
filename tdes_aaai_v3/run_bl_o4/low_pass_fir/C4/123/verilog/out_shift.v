module out_shift #(
    parameter DATA_W = 20,
    parameter GAIN_W = 4,
    parameter ACC_W  = 44
) (
    input  wire signed [ACC_W-1:0]         acc,
    output wire signed [DATA_W+GAIN_W-1:0] out
);
    // Scale down accumulator by DATA_W bits (arithmetic right shift)
    // Sign-extension is preserved by Verilog's >>> operator
    assign out = acc >>> DATA_W;
endmodule