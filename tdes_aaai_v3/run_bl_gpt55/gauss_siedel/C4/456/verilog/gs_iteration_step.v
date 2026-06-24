`timescale 1ns/1ps

module gs_iteration_step #(
    parameter DATA_WIDTH = 32,
    parameter FRAC       = 16
)(
    input  signed [DATA_WIDTH-1:0] a12,
    input  signed [DATA_WIDTH-1:0] a21,
    input  signed [DATA_WIDTH-1:0] b1,
    input  signed [DATA_WIDTH-1:0] b2,
    input  signed [DATA_WIDTH-1:0] inv_a11,
    input  signed [DATA_WIDTH-1:0] inv_a22,
    input  signed [DATA_WIDTH-1:0] x1_current,
    input  signed [DATA_WIDTH-1:0] x2_current,
    output signed [DATA_WIDTH-1:0] x1_next,
    output signed [DATA_WIDTH-1:0] x2_next
);

    assign x1_next = {DATA_WIDTH{1'b0}};
    assign x2_next = {DATA_WIDTH{1'b0}};

endmodule