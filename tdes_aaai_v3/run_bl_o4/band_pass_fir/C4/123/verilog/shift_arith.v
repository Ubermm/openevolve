module shift_arith #(
    parameter integer IN_W   = 64,
    parameter integer OUT_W  = 24,
    parameter integer SHIFT  = 20
) (
    input  wire signed [IN_W-1:0]   in,
    output wire signed [OUT_W-1:0]  out
);
    // Simple arithmetic right shift (no rounding)
    wire signed [IN_W-1:0] shifted = in >>> SHIFT;
    assign out = shifted[OUT_W-1:0];
endmodule