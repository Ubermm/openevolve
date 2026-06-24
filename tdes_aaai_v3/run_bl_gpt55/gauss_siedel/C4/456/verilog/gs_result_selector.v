`timescale 1ns/1ps

module gs_result_selector #(
    parameter DATA_WIDTH = 32,
    parameter FRAC       = 16
)(
    input  signed [DATA_WIDTH-1:0] a11,
    input  signed [DATA_WIDTH-1:0] a12,
    input  signed [DATA_WIDTH-1:0] a21,
    input  signed [DATA_WIDTH-1:0] a22,
    input  signed [DATA_WIDTH-1:0] b1,
    input  signed [DATA_WIDTH-1:0] b2,
    input  signed [DATA_WIDTH-1:0] fallback_x1,
    input  signed [DATA_WIDTH-1:0] fallback_x2,
    output signed [DATA_WIDTH-1:0] selected_x1,
    output signed [DATA_WIDTH-1:0] selected_x2,
    output override_used
);

    assign selected_x1   = {DATA_WIDTH{1'b0}};
    assign selected_x2   = {DATA_WIDTH{1'b0}};
    assign override_used = 1'b0;

endmodule