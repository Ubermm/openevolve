module scaler #(
    parameter DATA_W  = 20,
    parameter GAIN_W  = 4,
    parameter SUM_W   = 64,
    // coefficient quantization = 32768 → 2^15
    parameter COEFF_W = 15
) (
    input  signed [SUM_W-1:0]            sum_in,
    output signed [DATA_W+GAIN_W-1:0]    data_out
);
    // Arithmetic right‐shift by 15 bits to remove the fractional scaling
    assign data_out = sum_in >>> COEFF_W;
endmodule