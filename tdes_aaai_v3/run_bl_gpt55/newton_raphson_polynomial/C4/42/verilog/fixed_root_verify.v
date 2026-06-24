module fixed_root_verify #(
    parameter EXT_WIDTH = 64
)(
    input signed [EXT_WIDTH-1:0] p_value,
    input signed [EXT_WIDTH-1:0] tolerance,
    output valid
);
    assign valid = 0;
endmodule
