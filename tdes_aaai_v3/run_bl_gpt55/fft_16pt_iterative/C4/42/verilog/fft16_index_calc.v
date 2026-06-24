module fft16_index_calc #(
    parameter N = 16
) (
    input  [2:0] stage,
    input  [3:0] butterfly,
    output reg [3:0] p_idx,
    output reg [3:0] q_idx,
    output reg [3:0] tw_idx
);

    always @* begin
        p_idx  = 4'd0;
        q_idx  = 4'd0;
        tw_idx = 4'd0;

        case (stage)
            3'd0: begin
                p_idx  = {butterfly[2:0], 1'b0};
                q_idx  = {butterfly[2:0], 1'b0} + 4'd1;
                tw_idx = 4'd0;
            end

            3'd1: begin
                p_idx  = {butterfly[2:1], 1'b0, butterfly[0]};
                q_idx  = {butterfly[2:1], 1'b0, butterfly[0]} + 4'd2;
                tw_idx = {1'b0, butterfly[0], 2'b00};
            end

            3'd2: begin
                p_idx  = {butterfly[2], 1'b0, butterfly[1:0]};
                q_idx  = {butterfly[2], 1'b0, butterfly[1:0]} + 4'd4;
                tw_idx = {1'b0, butterfly[1:0], 1'b0};
            end

            3'd3: begin
                p_idx  = {1'b0, butterfly[2:0]};
                q_idx  = {1'b1, butterfly[2:0]};
                tw_idx = {1'b0, butterfly[2:0]};
            end

            default: begin
                p_idx  = 4'd0;
                q_idx  = 4'd0;
                tw_idx = 4'd0;
            end
        endcase
    end

endmodule