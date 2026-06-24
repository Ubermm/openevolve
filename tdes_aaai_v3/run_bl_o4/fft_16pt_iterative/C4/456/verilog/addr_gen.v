module addr_gen (
    input  wire [1:0] stage,
    input  wire [2:0] idx,
    output reg  [3:0] p,
    output reg  [3:0] q,
    output reg  [3:0] tw_idx
);

always @(*) begin
    case (stage)
        2'd0: begin
            // stage 0: m = 2, half-span = 1, N/m = 8 -> twiddle index always 0
            p      = idx << 1;        // idx * 2
            q      = p + 1;           // p + 1
            tw_idx = 4'd0;
        end
        2'd1: begin
            // stage 1: m = 4, half-span = 2, N/m = 4 -> twiddle index = j*4
            // idx = k*2 + j, with k = idx>>1, j = idx[0]
            p      = (idx[2:1] << 2) | idx[0];  // k*4 + j
            q      = p + 2;                     // p + half-span
            tw_idx = {idx[0], 2'b00};           // j * 4
        end
        2'd2: begin
            // stage 2: m = 8, half-span = 4, N/m = 2 -> twiddle index = j*2
            // idx = k*4 + j, with k = idx[2], j = idx[1:0]
            p      = (idx[2] << 3) | idx[1:0];  // k*8 + j
            q      = p + 4;                     // p + half-span
            tw_idx = {idx[1:0], 1'b0};          // j * 2
        end
        2'd3: begin
            // stage 3: m = 16, half-span = 8, N/m = 1 -> twiddle index = j
            // idx = j (only one block)
            p      = idx;                       // j
            q      = p + 8;                     // p + half-span
            tw_idx = idx;                       // j * 1
        end
        default: begin
            p      = 4'd0;
            q      = 4'd0;
            tw_idx = 4'd0;
        end
    endcase
end

endmodule