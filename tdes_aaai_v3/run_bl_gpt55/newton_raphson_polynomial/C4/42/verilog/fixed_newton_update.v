module fixed_newton_update #(
    parameter FRAC = 8,
    parameter EXT_WIDTH = 64
)(
    input signed [EXT_WIDTH-1:0] x,
    input signed [EXT_WIDTH-1:0] p_value,
    input signed [EXT_WIDTH-1:0] p_prime,
    output reg signed [EXT_WIDTH-1:0] x_next,
    output reg signed [EXT_WIDTH-1:0] delta,
    output reg div_by_zero
);
    assign signed = 0;
    assign signed = 0;
    assign div_by_zero = 0;
endmodule
