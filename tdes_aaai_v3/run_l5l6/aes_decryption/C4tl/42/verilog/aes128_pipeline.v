`timescale 1ns/1ps

module aes128_pipeline #(
    parameter PIPELINED      = 1,
    parameter UNROLL         = 1,
    parameter INLINE_KEY_EXP = 1
) (
    input              clk,
    input              rst,
    input              start,
    input              mode,         // fixed to 1'b1 for decryption
    input      [127:0] data_in,
    input      [127:0] key_in,
    input              valid_in,
    output reg [127:0] data_out,
    output reg         valid_out,
    output reg         done
);

    wire accept;
    assign accept = start & valid_in & mode;

    wire [1407:0] round_keys_in;
    wire [127:0]  initial_state;

    reg  [127:0]  state_pipe [0:9];
    reg  [1407:0] key_pipe   [0:9];
    reg  [9:0]    valid_pipe;

    wire [127:0] round_isr [0:9];
    wire [127:0] round_isb [0:9];
    wire [127:0] round_ark [0:9];
    wire [127:0] round_mix [0:8];

    integer si;
    genvar gi;

    aes128_key_expand u_key_expand (
        .key_in     (key_in),
        .round_keys (round_keys_in)
    );

    aes128_add_round_key u_initial_add_round_key (
        .state_in   (data_in),
        .round_key  (round_keys_in[1280 +: 128]), // rk10
        .state_out  (initial_state)
    );

    generate
        for (gi = 0; gi < 10; gi = gi + 1) begin : GEN_INV_ROUNDS
            aes128_inv_shiftrows u_inv_shiftrows (
                .state_in  (state_pipe[gi]),
                .state_out (round_isr[gi])
            );

            aes128_inv_subbytes u_inv_subbytes (
                .state_in  (round_isr[gi]),
                .state_out (round_isb[gi])
            );

            aes128_add_round_key u_add_round_key (
                .state_in  (round_isb[gi]),
                .round_key (key_pipe[gi][128*(9-gi) +: 128]),
                .state_out (round_ark[gi])
            );
        end

        for (gi = 0; gi < 9; gi = gi + 1) begin : GEN_INV_MIX
            aes128_inv_mixcolumns u_inv_mixcolumns (
                .state_in  (round_ark[gi]),
                .state_out (round_mix[gi])
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            for (si = 0; si < 10; si = si + 1) begin
                state_pipe[si] <= 128'b0;
                key_pipe[si]   <= 1408'b0;
            end
            valid_pipe <= 10'b0;
            data_out   <= 128'b0;
            valid_out  <= 1'b0;
            done       <= 1'b0;
        end else begin
            state_pipe[0] <= initial_state;
            key_pipe[0]   <= round_keys_in;
            valid_pipe[0] <= accept;

            for (si = 1; si < 10; si = si + 1) begin
                state_pipe[si] <= round_mix[si-1];
                key_pipe[si]   <= key_pipe[si-1];
                valid_pipe[si] <= valid_pipe[si-1];
            end

            data_out  <= round_ark[9];
            valid_out <= valid_pipe[9];
            done      <= valid_pipe[9];
        end
    end

endmodule