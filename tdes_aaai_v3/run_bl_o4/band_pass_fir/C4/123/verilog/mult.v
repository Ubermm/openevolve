module mult #(
    parameter A_W = 20,
    parameter B_W = 16
) (
    input  signed [A_W-1:0]    a,
    input  signed [B_W-1:0]    b,
    output signed [A_W+B_W-1:0] p
);
    // Combinational signed multiply
    assign p = a * b;
endmodule