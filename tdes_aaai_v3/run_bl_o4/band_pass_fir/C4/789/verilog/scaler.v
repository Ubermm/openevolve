module scaler #(
    parameter integer DATA_W = 20,
    parameter integer GAIN_W = 4
) (
    input  wire signed [63:0]              mac_in,
    output wire signed [DATA_W+GAIN_W-1:0] data_out
);
    // Combinational scaling: arithmetic right shift by DATA_W to remove fractional bits
    assign data_out = mac_in >>> DATA_W;
endmodule