module gd_output_quantizer #(
    parameter N     = 16,
    parameter XW    = 28,
    parameter GUARD = 8
)(
    input  signed [XW-1:0] x_int,
    output signed [N-1:0]  x_out
);

    assign x_out = $signed(x_int) >>> GUARD;

endmodule