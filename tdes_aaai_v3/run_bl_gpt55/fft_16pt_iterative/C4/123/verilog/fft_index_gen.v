`timescale 1ns/1ps

module fft_index_gen #(
    parameter N = 16,
    parameter LOGN = 4
) (
    input  [LOGN-1:0] stage_idx,
    input  [LOGN-1:0] bfly_idx,
    output [LOGN-1:0] p_idx,
    output [LOGN-1:0] q_idx,
    output [LOGN-1:0] tw_idx,
    output last_bfly,
    output last_stage
);

    /*
        Radix-2 DIT indexing for one complete stage.

        For stage s:
          half_size = 2^s
          span      = 2^(s+1)

        A linear butterfly counter bfly_idx = 0 .. N/2-1 is mapped to:
          group = bfly_idx / half_size
          j     = bfly_idx % half_size

          p_idx = group * span + j
          q_idx = p_idx + half_size
          tw_idx = j * (N / span)

        For N=16:
          stage 0: (0,1),(2,3),... tw=0
          stage 1: (0,2) tw=0, (1,3) tw=4, ...
          stage 2: (0,4) tw=0, (1,5) tw=2, ...
          stage 3: (0,8) tw=0, (1,9) tw=1, ...
    */

    reg [LOGN-1:0] p_r;
    reg [LOGN-1:0] q_r;
    reg [LOGN-1:0] tw_r;

    reg [LOGN-1:0] half_size;
    reg [LOGN-1:0] j;
    reg [LOGN-1:0] group;

    integer i;

    always @* begin
        half_size = {LOGN{1'b0}};
        j         = {LOGN{1'b0}};
        group     = {LOGN{1'b0}};
        p_r       = {LOGN{1'b0}};
        q_r       = {LOGN{1'b0}};
        tw_r      = {LOGN{1'b0}};

        half_size = ({{(LOGN-1){1'b0}}, 1'b1} << stage_idx);

        for (i = 0; i < LOGN; i = i + 1) begin
            if (i < stage_idx)
                j[i] = bfly_idx[i];
            else
                j[i] = 1'b0;
        end

        group = bfly_idx >> stage_idx;

        p_r = (group << (stage_idx + {{(LOGN-1){1'b0}}, 1'b1})) | j;
        q_r = p_r + half_size;

        if (stage_idx < (LOGN-1))
            tw_r = j << ((LOGN-1) - stage_idx);
        else
            tw_r = j;
    end

    assign p_idx = p_r;
    assign q_idx = q_r;
    assign tw_idx = tw_r;

    assign last_bfly  = (bfly_idx == ((N/2)-1));
    assign last_stage = (stage_idx == (LOGN-1));

endmodule