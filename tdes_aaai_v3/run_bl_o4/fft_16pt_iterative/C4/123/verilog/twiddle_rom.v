module twiddle_rom #(
    parameter COEFF_W = 16
) (
    input  wire             mode,    // 0: FFT, 1: IFFT
    input  wire      [3:0]  idx,     // Twiddle index 0..15
    output reg signed [COEFF_W-1:0] cos_o,
    output reg signed [COEFF_W-1:0] sin_o
);
    // Base Q1.15 table for W[k] = cos(2πk/16) + j·sin(2πk/16)
    reg signed [COEFF_W-1:0] cos_tmp;
    reg signed [COEFF_W-1:0] sin_tmp;
    always @(*) begin
        case (idx)
            4'd0:  begin cos_tmp = 16'sh7FFF; sin_tmp = 16'sh0000; end //  1.0,  0.0
            4'd1:  begin cos_tmp = 16'sh7642; sin_tmp = 16'sh30FC; end //  cos(pi/8),  sin(pi/8)
            4'd2:  begin cos_tmp = 16'sh5A82; sin_tmp = 16'sh5A82; end //  cos(pi/4),  sin(pi/4)
            4'd3:  begin cos_tmp = 16'sh30FC; sin_tmp = 16'sh7642; end //  cos(3pi/8), sin(3pi/8)
            4'd4:  begin cos_tmp = 16'sh0000; sin_tmp = 16'sh7FFF; end //  0.0, 1.0
            4'd5:  begin cos_tmp = 16'hCF04; sin_tmp = 16'h7642; end //  cos(5pi/8), sin(5pi/8)
            4'd6:  begin cos_tmp = 16'hA57E; sin_tmp = 16'h5A82; end //  cos(6pi/8), sin(6pi/8)
            4'd7:  begin cos_tmp = 16'h89BE; sin_tmp = 16'h30FC; end //  cos(7pi/8), sin(7pi/8)
            4'd8:  begin cos_tmp = 16'h8000; sin_tmp = 16'h0000; end // -1.0, 0.0
            4'd9:  begin cos_tmp = 16'h89BE; sin_tmp = 16'hCF04; end //  cos(9pi/8), sin(9pi/8)
            4'd10: begin cos_tmp = 16'hA57E; sin_tmp = 16'hA57E; end // cos(10pi/8), sin(10pi/8)
            4'd11: begin cos_tmp = 16'hCF04; sin_tmp = 16'h89BE; end // cos(11pi/8), sin(11pi/8)
            4'd12: begin cos_tmp = 16'h0000; sin_tmp = 16'h8000; end //  0.0, -1.0
            4'd13: begin cos_tmp = 16'h30FC; sin_tmp = 16'h89BE; end // cos(13pi/8), sin(13pi/8)
            4'd14: begin cos_tmp = 16'h5A82; sin_tmp = 16'hA57E; end // cos(14pi/8), sin(14pi/8)
            4'd15: begin cos_tmp = 16'h7642; sin_tmp = 16'hCF04; end // cos(15pi/8), sin(15pi/8)
            default: begin cos_tmp = {COEFF_W{1'b0}}; sin_tmp = {COEFF_W{1'b0}}; end
        endcase
        cos_o = cos_tmp;
        // For FFT (mode=0) use W = cos - j·sin  => sin_o = +sin_tmp (tr_real = xr*cos + xi*sin)
        // For IFFT(mode=1) use W = cos + j·sin => sin_o = -sin_tmp
        sin_o = mode ? -sin_tmp : sin_tmp;
    end
endmodule