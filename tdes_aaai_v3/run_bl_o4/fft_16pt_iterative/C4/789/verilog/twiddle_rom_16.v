module twiddle_rom_16(
    input  wire        clk,    // clock (not used, outputs are combinational)
    input  wire        rst,    // reset (not used)
    input  wire        mode,   // 0: FFT, 1: IFFT (conjugate)
    input  wire [3:0]  addr,   // twiddle index k = 0..15
    output reg  signed [15:0] cos, 
    output reg  signed [15:0] sin
);

    // Combinational lookup table for Q1.15 twiddle factors
    // W[k] = cos(2*pi*k/16) - j*sin(2*pi*k/16)  for FFT mode (mode=0)
    // For IFFT mode (mode=1) we take the conjugate => sin -> -sin
    always @(*) begin
        case (addr)
            4'd0:  begin cos = 16'sh7FFF; sin = 16'sh0000; end //  1.0,   0.0
            4'd1:  begin cos = 16'sh7642; sin = 16'sh30FC; end //  cos(pi/8), sin(pi/8)
            4'd2:  begin cos = 16'sh5A82; sin = 16'sh5A82; end //  cos(pi/4), sin(pi/4)
            4'd3:  begin cos = 16'sh30FC; sin = 16'sh7642; end //  cos(3pi/8), sin(3pi/8)
            4'd4:  begin cos = 16'sh0000; sin = 16'sh7FFF; end //  0.0,   1.0
            4'd5:  begin cos = 16'shCF04; sin = 16'sh7642; end //  cos(5pi/8), sin(5pi/8)
            4'd6:  begin cos = 16'shA57E; sin = 16'sh5A82; end //  cos(6pi/8), sin(6pi/8)
            4'd7:  begin cos = 16'sh89BE; sin = 16'sh30FC; end //  cos(7pi/8), sin(7pi/8)
            4'd8:  begin cos = 16'sh8000; sin = 16'sh0000; end // -1.0,   0.0
            4'd9:  begin cos = 16'sh89BE; sin = 16'shCF04; end //  cos(9pi/8), sin(9pi/8)
            4'd10: begin cos = 16'shA57E; sin = 16'shA57E; end //  cos(10pi/8), sin(10pi/8)
            4'd11: begin cos = 16'shCF04; sin = 16'sh89BE; end //  cos(11pi/8), sin(11pi/8)
            4'd12: begin cos = 16'sh0000; sin = 16'sh8000; end //  0.0,  -1.0
            4'd13: begin cos = 16'sh30FC; sin = 16'sh89BE; end //  cos(13pi/8), sin(13pi/8)
            4'd14: begin cos = 16'sh5A82; sin = 16'shA57E; end //  cos(14pi/8), sin(14pi/8)
            4'd15: begin cos = 16'sh7642; sin = 16'shCF04; end //  cos(15pi/8), sin(15pi/8)
            default: begin cos = 16'sh0000; sin = 16'sh0000; end
        endcase
        // apply conjugation for IFFT
        if (mode)
            sin = -sin;
    end

endmodule