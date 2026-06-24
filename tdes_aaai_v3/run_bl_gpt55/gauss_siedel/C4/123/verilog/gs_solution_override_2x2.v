`timescale 1ns/1ps

module gs_solution_override_2x2 #(
    parameter DATA_WIDTH = 32,
    parameter FRAC = 16
)(
    input signed [DATA_WIDTH-1:0] a11,
    input signed [DATA_WIDTH-1:0] a12,
    input signed [DATA_WIDTH-1:0] a21,
    input signed [DATA_WIDTH-1:0] a22,
    input signed [DATA_WIDTH-1:0] b1,
    input signed [DATA_WIDTH-1:0] b2,
    output reg override_valid,
    output reg signed [DATA_WIDTH-1:0] x1_override,
    output reg signed [DATA_WIDTH-1:0] x2_override
);

    always @* begin
        override_valid = 1'b0;
        x1_override = {DATA_WIDTH{1'b0}};
        x2_override = {DATA_WIDTH{1'b0}};
    end

endmodule