module lowpass_fir_output_quantize #(
    parameter ACC_W      = 64,
    parameter OUT_W      = 24,
    parameter SHIFT_BITS = 15
) (
    input  signed [ACC_W-1:0] acc,
    output signed [OUT_W-1:0] data_out
);

    wire signed [ACC_W-1:0] shifted_acc;

    assign shifted_acc = acc >>> SHIFT_BITS;
    assign data_out    = shifted_acc[OUT_W-1:0];

endmodule