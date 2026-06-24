module addr_gen (
    input  wire [1:0] stage,    // FFT stage index 0..3
    input  wire [2:0] bcnt,     // butterfly count 0..7
    output reg  [3:0] p_addr,   // lower-address index
    output reg  [3:0] q_addr,   // upper-address index
    output reg  [3:0] tw_addr   // twiddle ROM index
);
    // FFT size
    localparam integer N = 16;

    // distance between paired points
    wire [3:0] span   = 4'd1 << stage;
    // index within the span (lower half)
    wire [2:0] bf_idx = bcnt & (span - 1);
    // which group of size 2*span
    wire [3:0] grp_idx= bcnt >> stage;
    // twiddle stride = N >> (stage+1)
    wire [3:0] stride = N >> (stage + 1);

    always @(*) begin
        // compute the low and high addresses
        p_addr = (grp_idx << (stage + 1)) + bf_idx;
        q_addr = p_addr + span;
        // twiddle index for this butterfly
        tw_addr = bf_idx * stride;
    end
endmodule