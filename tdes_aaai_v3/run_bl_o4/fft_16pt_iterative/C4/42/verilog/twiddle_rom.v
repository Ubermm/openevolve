module twiddle_rom (
    input  wire        mode,       // 0: FFT (cos – j·sin), 1: IFFT (cos + j·sin)
    input  wire [3:0]  tw_idx,     // twiddle index 0..15
    output reg  signed [15:0] cos_q,
    output reg  signed [15:0] sin_q
);

    // Internal un-modified lookup table (Q1.15)
    reg signed [15:0] cos_tmp, sin_tmp;

    always @(*) begin
        case (tw_idx)
            4'd0:  begin cos_tmp = 16'h7FFF; sin_tmp = 16'h0000; end
            4'd1:  begin cos_tmp = 16'h7642; sin_tmp = 16'h30FC; end
            4'd2:  begin cos_tmp = 16'h5A82; sin_tmp = 16'h5A82; end
            4'd3:  begin cos_tmp = 16'h30FC; sin_tmp = 16'h7642; end
            4'd4:  begin cos_tmp = 16'h0000; sin_tmp = 16'h7FFF; end
            4'd5:  begin cos_tmp = 16'hCF04; sin_tmp = 16'h7642; end
            4'd6:  begin cos_tmp = 16'hA57E; sin_tmp = 16'h5A82; end
            4'd7:  begin cos_tmp = 16'h89BE; sin_tmp = 16'h30FC; end
            4'd8:  begin cos_tmp = 16'h8000; sin_tmp = 16'h0000; end
            4'd9:  begin cos_tmp = 16'h89BE; sin_tmp = 16'hCF04; end
            4'd10: begin cos_tmp = 16'hA57E; sin_tmp = 16'hA57E; end
            4'd11: begin cos_tmp = 16'hCF04; sin_tmp = 16'h89BE; end
            4'd12: begin cos_tmp = 16'h0000; sin_tmp = 16'h8000; end
            4'd13: begin cos_tmp = 16'h30FC; sin_tmp = 16'h89BE; end
            4'd14: begin cos_tmp = 16'h5A82; sin_tmp = 16'hA57E; end
            4'd15: begin cos_tmp = 16'h7642; sin_tmp = 16'hCF04; end
            default: begin cos_tmp = 16'h0000; sin_tmp = 16'h0000; end
        endcase

        // Apply mode: FFT (0) => e^{-jθ} = cos - j·sin; IFFT (1) => cos + j·sin
        cos_q = cos_tmp;
        sin_q = mode ? sin_tmp : -sin_tmp;
    end

endmodule