module fixed_convergence_check #(
    parameter EXT_WIDTH = 64
)(
    input signed [EXT_WIDTH-1:0] p_value,
    input signed [EXT_WIDTH-1:0] delta,
    input signed [EXT_WIDTH-1:0] tolerance,
    output poly_small,
    output delta_small
);
    assign poly_small = 0;
    assign delta_small = 0;
endmodule
