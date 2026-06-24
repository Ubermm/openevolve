module add_tree #(
    parameter integer N     = 51,
    parameter integer W_IN  = 37,
    parameter integer W_OUT = 64
) (
    input  wire [N*W_IN-1:0]       in_data,
    output reg  signed [W_OUT-1:0] out
);

    integer i;
    reg signed [W_IN-1:0] in_val;
    
    // Combinational accumulation of N signed W_IN-bit values into W_OUT-bit sum
    always @* begin
        out = {W_OUT{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            // extract the i-th W_IN-bit signed partial product
            in_val = in_data[i*W_IN + W_IN - 1 -: W_IN];
            // accumulate into W_OUT-bit signed result
            out = out + in_val;
        end
    end

endmodule