module twiddle_rom #(
    parameter COEFF_W = 16
) (
    input  wire             [3:0]               addr,
    output reg signed [COEFF_W-1:0]             cos_q15,
    output reg signed [COEFF_W-1:0]             sin_q15
);

always @(*) begin
    case (addr)
        4'd0: begin cos_q15 = 16'h7FFF; sin_q15 = 16'h0000; end  //  1.0,   0.0
        4'd1: begin cos_q15 = 16'h7642; sin_q15 = 16'hCF04; end  //  cos(pi/8), -sin(pi/8)
        4'd2: begin cos_q15 = 16'h5A82; sin_q15 = 16'hA57E; end  //  cos(pi/4), -sin(pi/4)
        4'd3: begin cos_q15 = 16'h30FC; sin_q15 = 16'h89BE; end  //  cos(3pi/8), -sin(3pi/8)
        4'd4: begin cos_q15 = 16'h0000; sin_q15 = 16'h8001; end  //  0.0,   -1.0
        4'd5: begin cos_q15 = 16'hCF04; sin_q15 = 16'h89BE; end  //  cos(5pi/8), -sin(5pi/8)
        4'd6: begin cos_q15 = 16'hA57E; sin_q15 = 16'hA57E; end  //  cos(6pi/8), -sin(6pi/8)
        4'd7: begin cos_q15 = 16'h89BE; sin_q15 = 16'hCF04; end  //  cos(7pi/8), -sin(7pi/8)
        4'd8: begin cos_q15 = 16'h8000; sin_q15 = 16'h0000; end  // -1.0,   0.0
        default: begin
            cos_q15 = {COEFF_W{1'b0}};
            sin_q15 = {COEFF_W{1'b0}};
        end
    endcase
end

endmodule