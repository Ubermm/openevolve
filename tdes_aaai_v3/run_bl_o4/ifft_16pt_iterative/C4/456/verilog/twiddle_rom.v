module twiddle_rom #(
    parameter COEFF_W = 16
) (
    input  wire [3:0]               addr,
    input  wire                     mode,   // 0: FFT (negate sin), 1: IFFT (use sin)
    output reg signed [COEFF_W-1:0] cos_w,
    output reg signed [COEFF_W-1:0] sin_w
);

    // Base Q1.15 twiddle factors (cos, +sin)
    reg signed [COEFF_W-1:0] cos_b;
    reg signed [COEFF_W-1:0] sin_b;

    always @(*) begin
        case (addr)
            4'd0: begin cos_b = 16'sd 32767; sin_b = 16'sd     0; end
            4'd1: begin cos_b = 16'sd 30274; sin_b = 16'sd  12540; end
            4'd2: begin cos_b = 16'sd 23170; sin_b = 16'sd  23170; end
            4'd3: begin cos_b = 16'sd 12540; sin_b = 16'sd  30274; end
            4'd4: begin cos_b = 16'sd     0; sin_b = 16'sd  32767; end
            4'd5: begin cos_b = -16'sd 12540; sin_b = 16'sd  30274; end
            4'd6: begin cos_b = -16'sd 23170; sin_b = 16'sd  23170; end
            4'd7: begin cos_b = -16'sd 30274; sin_b = 16'sd  12540; end
            4'd8: begin cos_b = -16'sd 32768; sin_b = 16'sd     0; end
            default: begin cos_b = {COEFF_W{1'b0}}; sin_b = {COEFF_W{1'b0}}; end
        endcase

        // Always pass cosine. Sin is negated for FFT (mode=0), used as-is for IFFT (mode=1).
        cos_w = cos_b;
        sin_w = mode ? sin_b : -sin_b;
    end

endmodule