`timescale 1ns/1ps

module gs_fixed_reciprocal #(
    parameter DATA_WIDTH = 32,
    parameter FRAC       = 16
)(
    input  signed [DATA_WIDTH-1:0] a,
    output signed [DATA_WIDTH-1:0] reciprocal
);

    assign reciprocal = {DATA_WIDTH{1'b0}};

endmodule