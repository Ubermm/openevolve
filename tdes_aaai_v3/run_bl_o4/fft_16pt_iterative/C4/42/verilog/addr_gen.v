module addr_gen (
    input  wire        clk,
    input  wire        rst,
    input  wire  [1:0] stage,
    input  wire  [2:0] bf_cnt,
    output reg   [3:0] p_addr,
    output reg   [3:0] q_addr,
    output reg   [3:0] tw_idx
);

    // Compute butterfly distance m = 2^stage
    wire [3:0] m       = 4'd1 << stage;
    // position within the current half-butterfly (0 .. m-1)
    wire [3:0] pos     = bf_cnt & (m - 1);
    // which block of size 2*m (0 .. (N/2)/m - 1)
    wire [3:0] blk     = bf_cnt >> stage;
    // base index for the butterfly pair: blk * (2*m) + pos
    wire [4:0] base_full = (blk << (stage + 1)) + pos;
    wire [3:0] base    = base_full[3:0];  // wrap mod N=16
    // twiddle-step = (N/2)/m = 8 >> stage
    wire [3:0] tw_step = 4'd8 >> stage;
    // twiddle index = pos * tw_step
    wire [5:0] tidx_full = pos * tw_step;
    wire [3:0] tidx    = tidx_full[3:0];

    // next-cycle outputs
    wire [3:0] p_next  = base;
    wire [3:0] q_next  = base + m;
    wire [3:0] t_next  = tidx;

    // register outputs (1-cycle pipeline)
    always @(posedge clk) begin
        if (rst) begin
            p_addr <= 4'd0;
            q_addr <= 4'd0;
            tw_idx <= 4'd0;
        end else begin
            p_addr <= p_next;
            q_addr <= q_next;
            tw_idx <= t_next;
        end
    end

endmodule