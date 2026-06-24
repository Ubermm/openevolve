`timescale 1ns/1ps

module fft16_addr_gen #(
    parameter N = 16,
    parameter ADDR_W = 4
) (
    input  [1:0] stage,
    input  [2:0] butterfly_idx,
    output [ADDR_W-1:0] p_addr,
    output [ADDR_W-1:0] q_addr,
    output [ADDR_W-1:0] tw_addr
);

    reg [ADDR_W-1:0] p_r;
    reg [ADDR_W-1:0] q_r;
    reg [ADDR_W-1:0] tw_r;

    assign p_addr  = p_r;
    assign q_addr  = q_r;
    assign tw_addr = tw_r;

    always @* begin
        p_r  = {ADDR_W{1'b0}};
        q_r  = {ADDR_W{1'b0}};
        tw_r = {ADDR_W{1'b0}};

        case (stage)
            2'd0: begin
                // m = 2, half = 1, twiddle step = 8
                // (0,1), (2,3), ..., (14,15), all W[0]
                p_r  = {butterfly_idx, 1'b0};
                q_r  = {butterfly_idx, 1'b0} + {{(ADDR_W-1){1'b0}}, 1'b1};
                tw_r = {ADDR_W{1'b0}};
            end

            2'd1: begin
                // m = 4, half = 2, twiddle step = 4
                // idx[0] selects j, idx[2:1] selects group
                p_r  = {butterfly_idx[2:1], 1'b0, butterfly_idx[0]};
                q_r  = {butterfly_idx[2:1], 1'b0, butterfly_idx[0]} + {{(ADDR_W-2){1'b0}}, 2'd2};
                tw_r = butterfly_idx[0] ? {{(ADDR_W-3){1'b0}}, 3'd4} : {ADDR_W{1'b0}};
            end

            2'd2: begin
                // m = 8, half = 4, twiddle step = 2
                // idx[1:0] selects j, idx[2] selects group
                p_r  = {butterfly_idx[2], 1'b0, butterfly_idx[1:0]};
                q_r  = {butterfly_idx[2], 1'b0, butterfly_idx[1:0]} + {{(ADDR_W-3){1'b0}}, 3'd4};
                tw_r = {{(ADDR_W-3){1'b0}}, butterfly_idx[1:0], 1'b0};
            end

            default: begin
                // stage 3: m = 16, half = 8, twiddle step = 1
                // idx[2:0] selects j
                p_r  = {{(ADDR_W-3){1'b0}}, butterfly_idx};
                q_r  = {{(ADDR_W-3){1'b0}}, butterfly_idx} + {{(ADDR_W-4){1'b0}}, 4'd8};
                tw_r = {{(ADDR_W-3){1'b0}}, butterfly_idx};
            end
        endcase
    end

endmodule