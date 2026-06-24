module bit_rev (
    input        clk,
    input  [3:0] in,
    output reg [3:0] out
);
    // Final pipeline stage: bit‐reverse a 4‐bit index
    // in[3] is MSB, in[0] is LSB; output MSB<=in[0], LSB<=in[3]
    // No reset here – simply pipeline the bit‐reversal mapping
    always @(posedge clk) begin
        out <= { in[0], in[1], in[2], in[3] };
    end
endmodule