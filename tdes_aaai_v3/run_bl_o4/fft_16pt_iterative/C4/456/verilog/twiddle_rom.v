module twiddle_rom #(
    parameter COEFF_W = 16
) (
    input  wire [3:0]                 idx,      // twiddle index k = 0..8 (only 0..7 used for N=16)
    input  wire                       mode,     // 0: FFT (e^{-j2πk/N}), 1: IFFT (e^{+j2πk/N})
    output reg  signed [COEFF_W-1:0]  cos_q15,
    output reg  signed [COEFF_W-1:0]  sin_q15
);

    // Internal values for positive-sin table
    reg signed [COEFF_W-1:0] cos_val;
    reg signed [COEFF_W-1:0] sin_val;

    always @(*) begin
        case (idx)
            4'd0: begin
                // W[0] =  1.0 + j0.0
                cos_val =  16'sh7FFF;  // +32767
                sin_val =  16'sh0000;  //  0
            end
            4'd1: begin
                // W[1] = cos(pi/8)  - j sin(pi/8) = 0.9239  - j0.3827
                cos_val =  16'sh7642;  // +30274
                sin_val =  16'sh30FC;  // +12540
            end
            4'd2: begin
                // W[2] = cos(pi/4)  - j sin(pi/4) = 0.7071  - j0.7071
                cos_val =  16'sh5A82;  // +23170
                sin_val =  16'sh5A82;  // +23170
            end
            4'd3: begin
                // W[3] = cos(3pi/8) - j sin(3pi/8) = 0.3827  - j0.9239
                cos_val =  16'sh30FC;  // +12540
                sin_val =  16'sh7642;  // +30274
            end
            4'd4: begin
                // W[4] = cos(pi/2)  - j sin(pi/2) = 0.0     - j1.0
                cos_val =  16'sh0000;  //  0
                sin_val =  16'sh7FFF;  // +32767
            end
            4'd5: begin
                // W[5] = cos(5pi/8) - j sin(5pi/8) = -0.3827 - j0.9239
                cos_val = -16'sh30FC;  // -12540
                sin_val =  16'sh7642;  // +30274
            end
            4'd6: begin
                // W[6] = cos(3pi/4) - j sin(3pi/4) = -0.7071 - j0.7071
                cos_val = -16'sh5A82;  // -23170
                sin_val =  16'sh5A82;  // +23170
            end
            4'd7: begin
                // W[7] = cos(7pi/8) - j sin(7pi/8) = -0.9239 - j0.3827
                cos_val = -16'sh7642;  // -30274
                sin_val =  16'sh30FC;  // +12540
            end
            4'd8: begin
                // W[8] = cos(pi)   - j sin(pi) = -1.0   - j0.0
                cos_val = -16'sh8000;  // -32768
                sin_val =  16'sh0000;  //  0
            end
            default: begin
                cos_val = {COEFF_W{1'b0}};
                sin_val = {COEFF_W{1'b0}};
            end
        endcase

        // Assign outputs: for FFT mode (mode=0) we want e^{-jθ} = cos - j*sin
        // so sin_q15 = -sin_val when mode=0; for IFFT (mode=1) sin_q15 = +sin_val
        cos_q15 = cos_val;
        sin_q15 = mode ? sin_val : -sin_val;
    end

endmodule