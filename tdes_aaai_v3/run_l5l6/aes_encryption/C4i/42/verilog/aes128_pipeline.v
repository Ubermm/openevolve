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

    reg [127:0] state_pipe [0:9];
    reg [127:0] key_pipe   [0:9];
    reg         valid_pipe [0:9];

    wire        accept;
    assign accept = start & valid_in;

    wire [127:0] round_state [1:9];
    wire [127:0] round_key   [1:9];

    genvar r;
    generate
        for (r = 1; r <= 9; r = r + 1) begin : GEN_AES_ROUNDS
            aes_key_expand #(
                .ROUND(r)
            ) u_key_expand (
                .key_in (key_pipe[r-1]),
                .key_out(round_key[r])
            );

            aes_round u_round (
                .state_in (state_pipe[r-1]),
                .round_key(round_key[r]),
                .state_out(round_state[r])
            );
        end
    endgenerate

    wire [127:0] final_key;
    wire [127:0] final_sub;
    wire [127:0] final_shift;
    wire [127:0] final_state;

    aes_key_expand #(
        .ROUND(10)
    ) u_final_key_expand (
        .key_in (key_pipe[9]),
        .key_out(final_key)
    );

    aes_subbytes u_final_subbytes (
        .state_in (state_pipe[9]),
        .state_out(final_sub)
    );

    aes_shiftrows u_final_shiftrows (
        .state_in (final_sub),
        .state_out(final_shift)
    );

    assign final_state = final_shift ^ final_key;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 10; i = i + 1) begin
                state_pipe[i] <= 128'b0;
                key_pipe[i]   <= 128'b0;
                valid_pipe[i] <= 1'b0;
            end
            data_out  <= 128'b0;
            valid_out <= 1'b0;
            done      <= 1'b0;
        end else begin
            state_pipe[0] <= data_in ^ key_in;
            key_pipe[0]   <= key_in;
            valid_pipe[0] <= accept;

            for (i = 1; i < 10; i = i + 1) begin
                state_pipe[i] <= round_state[i];
                key_pipe[i]   <= round_key[i];
                valid_pipe[i] <= valid_pipe[i-1];
            end

            data_out  <= final_state;
            valid_out <= valid_pipe[9];
            done      <= valid_pipe[9];
        end
    end

endmodule