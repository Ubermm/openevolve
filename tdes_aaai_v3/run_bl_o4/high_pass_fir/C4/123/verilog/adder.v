module adder #(
    parameter W = 43
) (
    input  wire signed [W-1:0] a,
    input  wire signed [W-1:0] b,
    output wire signed [W-1:0] sum
);
    // Simple combinational adder for accumulation stage
    assign sum = a + b;
endmodule