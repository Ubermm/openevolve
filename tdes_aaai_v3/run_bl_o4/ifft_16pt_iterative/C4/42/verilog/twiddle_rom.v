module twiddle_rom #(
    parameter COEFF_W = 16
) (
    input  wire [3:0]                tw_idx,
    output reg  signed [COEFF_W-1:0] cos_q15,
    output reg  signed [COEFF_W-1:0] sin_q15
);
    // ROM for Q1.15 twiddle coefficients (conjugated for IFFT) for N=16
    // Twiddle: W_k = exp(+j*2*pi*k/16) = cos(2πk/16) + j*sin(2πk/16)
    // Conjugate => sin term negated
    always @* begin
        case (tw_idx)
            4'd0: begin
                cos_q15 =  16'sh7FFF;  // +1.0000
                sin_q15 =  16'sh0000;  // -0.0000
            end
            4'd1: begin
                cos_q15 =  16'sh7642;  //  0.9239
                sin_q15 = -16'sh30FC;  // -0.3827
            end
            4'd2: begin
                cos_q15 =  16'sh5A82;  //  0.7071
                sin_q15 = -16'sh5A82;  // -0.7071
            end
            4'd3: begin
                cos_q15 =  16'sh30FC;  //  0.3827
                sin_q15 = -16'sh7642;  // -0.9239
            end
            4'd4: begin
                cos_q15 =  16'sh0000;  //  0.0000
                sin_q15 = -16'sh7FFF;  // -1.0000
            end
            4'd5: begin
                cos_q15 = -16'sh30FC;  // -0.3827
                sin_q15 = -16'sh7642;  // -0.9239
            end
            4'd6: begin
                cos_q15 = -16'sh5A82;  // -0.7071
                sin_q15 = -16'sh5A82;  // -0.7071
            end
            4'd7: begin
                cos_q15 = -16'sh7642;  // -0.9239
                sin_q15 = -16'sh30FC;  // -0.3827
            end
            4'd8: begin
                cos_q15 = -16'sh8000;  // -1.0000
                sin_q15 =  16'sh0000;  //  0.0000
            end
            default: begin
                cos_q15 = {COEFF_W{1'b0}};
                sin_q15 = {COEFF_W{1'b0}};
            end
        endcase
    end
endmodule