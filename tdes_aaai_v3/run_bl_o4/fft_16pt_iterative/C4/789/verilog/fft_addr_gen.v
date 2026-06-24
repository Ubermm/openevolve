module fft_addr_gen(
    input  wire [1:0] stage,
    input  wire [3:0] cnt,
    output wire [3:0] addr_p,
    output wire [3:0] addr_q,
    output wire [3:0] tw_idx
);
    // FFT size
    localparam integer N = 16;

    // distance between elements in a butterfly half: half = 2**stage
    wire [3:0] half   = 4'd1 << stage;
    // twiddle index stride: stride = N / (2 * half)
    wire [3:0] stride = N >> (stage + 1);

    // which group this butterfly belongs to
    wire [3:0] group  = cnt >> stage;
    // base address of this group: group * (2 * half)
    wire [3:0] base   = group << (stage + 1);
    // position within the half-block: k = cnt % half
    wire [3:0] offset = cnt - (group << stage);

    // compute butterfly pair addresses
    assign addr_p = base + offset;
    assign addr_q = addr_p + half;
    // compute twiddle index
    assign tw_idx = offset * stride;

endmodule