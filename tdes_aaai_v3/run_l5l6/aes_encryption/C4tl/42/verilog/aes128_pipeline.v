`timescale 1ns/1ps

module aes128_pipeline #(
    parameter PIPELINED      = 1,
    parameter UNROLL         = 1,
    parameter INLINE_KEY_EXP = 1
) (
    input              clk,
    input              rst,
    input              start,
    input              mode,         // fixed to 1'b0 for encryption
    input      [127:0] data_in,
    input      [127:0] key_in,
    input              valid_in,
    output reg [127:0] data_out,
    output reg         valid_out,
    output reg         done
);

    reg  [127:0] state_pipe [0:9];
    reg  [127:0] key_pipe   [0:9];
    reg  [9:0]   valid_pipe;

    wire [127:0] next_key    [1:10];
    wire [127:0] next_state  [1:10];

    genvar gi;
    generate
        for (gi = 1; gi <= 10; gi = gi + 1) begin : AES_PIPE_STAGES
            aes_key_expand_round u_key_expand (
                .round   (gi[3:0]),
                .key_in  (key_pipe[gi-1]),
                .key_out (next_key[gi])
            );

            if (gi == 10) begin : FINAL_ROUND
                aes_round #(
                    .FINAL_ROUND(1)
                ) u_round (
                    .state_in  (state_pipe[gi-1]),
                    .round_key (next_key[gi]),
                    .state_out (next_state[gi])
                );
            end else begin : NORMAL_ROUND
                aes_round #(
                    .FINAL_ROUND(0)
                ) u_round (
                    .state_in  (state_pipe[gi-1]),
                    .round_key (next_key[gi]),
                    .state_out (next_state[gi])
                );
            end
        end
    endgenerate

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 10; i = i + 1) begin
                state_pipe[i] <= 128'd0;
                key_pipe[i]   <= 128'd0;
            end
            valid_pipe <= 10'd0;
            data_out   <= 128'd0;
            valid_out  <= 1'b0;
            done       <= 1'b0;
        end else begin
            state_pipe[0] <= data_in ^ key_in;
            key_pipe[0]   <= key_in;
            valid_pipe[0] <= start & valid_in & ~mode;

            for (i = 1; i < 10; i = i + 1) begin
                state_pipe[i] <= next_state[i];
                key_pipe[i]   <= next_key[i];
                valid_pipe[i] <= valid_pipe[i-1];
            end

            data_out  <= next_state[10];
            valid_out <= valid_pipe[9];
            done      <= valid_pipe[9];
        end
    end

endmodule