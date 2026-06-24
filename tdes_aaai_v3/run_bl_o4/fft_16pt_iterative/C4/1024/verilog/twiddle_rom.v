module twiddle_rom(
    input  wire        [3:0]        addr,
    input  wire                     mode,      // 0: FFT, 1: IFFT
    output reg  signed  [15:0]      cos_q15,
    output reg  signed  [15:0]      sin_q15
);

    // Base lookup table for full 16-point twiddle (Q1.15)
    // sin_lut holds sin(k*2pi/16) for k=0..15 (with sign)
    reg signed [15:0] cos_lut;
    reg signed [15:0] sin_lut;
    always @* begin
        case(addr)
            4'd0:  begin cos_lut = 16'sh7FFF; sin_lut =  16'sh0000; end  //  1.0,   0.0
            4'd1:  begin cos_lut = 16'sh7642; sin_lut =  16'sh30FC; end  //  π/8
            4'd2:  begin cos_lut = 16'sh5A82; sin_lut =  16'sh5A82; end  //  π/4
            4'd3:  begin cos_lut = 16'sh30FC; sin_lut =  16'sh7642; end  // 3π/8
            4'd4:  begin cos_lut = 16'sh0000; sin_lut =  16'sh7FFF; end  //  π/2
            4'd5:  begin cos_lut = -16'sh30FC; sin_lut =  16'sh7642; end  // 5π/8
            4'd6:  begin cos_lut = -16'sh5A82; sin_lut =  16'sh5A82; end  // 3π/4
            4'd7:  begin cos_lut = -16'sh7642; sin_lut =  16'sh30FC; end  // 7π/8
            4'd8:  begin cos_lut = -16'sh8000; sin_lut =  16'sh0000; end  //    π
            4'd9:  begin cos_lut = -16'sh7642; sin_lut = -16'sh30FC; end  // 9π/8
            4'd10: begin cos_lut = -16'sh5A82; sin_lut = -16'sh5A82; end  // 5π/4
            4'd11: begin cos_lut = -16'sh30FC; sin_lut = -16'sh7642; end  // 11π/8
            4'd12: begin cos_lut =  16'sh0000; sin_lut = -16'sh7FFF; end  // 3π/2
            4'd13: begin cos_lut =  16'sh30FC; sin_lut = -16'sh7642; end  // 13π/8
            4'd14: begin cos_lut =  16'sh5A82; sin_lut = -16'sh5A82; end  // 7π/4
            4'd15: begin cos_lut =  16'sh7642; sin_lut = -16'sh30FC; end  // 15π/8
            default: begin cos_lut = 16'sh0000; sin_lut = 16'sh0000; end
        endcase
    end

    // Apply conjugation for IFFT: 
    // FFT (mode=0): W = cos - j*sin  => sin_q15 = -sin_lut
    // IFFT(mode=1): W = cos + j*sin  => sin_q15 =  sin_lut
    always @* begin
        cos_q15 = cos_lut;
        sin_q15 = mode ? sin_lut : -sin_lut;
    end

endmodule