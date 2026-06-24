module gd_update #(
    parameter XW     = 28,
    parameter STEP_W = 62
)(
    input  signed [XW-1:0]     x_val,
    input  signed [STEP_W-1:0] step,
    output signed [XW-1:0]     x_next_int
);

    wire signed [XW-1:0] step_xw;

    generate
        if (STEP_W >= XW) begin : gen_step_truncate
            assign step_xw = step[XW-1:0];
        end else begin : gen_step_extend
            assign step_xw = {{(XW-STEP_W){step[STEP_W-1]}}, step};
        end
    endgenerate

    assign x_next_int = x_val - step_xw;

endmodule