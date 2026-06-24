`timescale 1ns/1ps

module fft_twiddle_rom #(
    parameter N = 16,
    parameter COEFF_W = 16,
    parameter LOGN = 4
) (
    input  [LOGN-1:0] tw_idx,
    output reg signed [COEFF_W-1:0] cos_q,
    output reg signed [COEFF_W-1:0] sin_q
);

    always @* begin
        case (tw_idx[3:0])
            4'd0: begin
                cos_q = 16'sh7FFF; //  32767
                sin_q = 16'sh0000; //      0
            end
            4'd1: begin
                cos_q = 16'sh7642; //  30274
                sin_q = 16'sh30FC; //  12540
            end
            4'd2: begin
                cos_q = 16'sh5A82; //  23170
                sin_q = 16'sh5A82; //  23170
            end
            4'd3: begin
                cos_q = 16'sh30FC; //  12540
                sin_q = 16'sh7642; //  30274
            end
            4'd4: begin
                cos_q = 16'sh0000; //      0
                sin_q = 16'sh7FFF; //  32767
            end
            4'd5: begin
                cos_q = 16'shCF04; // -12540
                sin_q = 16'sh7642; //  30274
            end
            4'd6: begin
                cos_q = 16'shA57E; // -23170
                sin_q = 16'sh5A82; //  23170
            end
            4'd7: begin
                cos_q = 16'sh89BE; // -30274
                sin_q = 16'sh30FC; //  12540
            end
            4'd8: begin
                cos_q = 16'sh8000; // -32768
                sin_q = 16'sh0000; //      0
            end
            4'd9: begin
                cos_q = 16'sh89BE; // -30274
                sin_q = 16'shCF04; // -12540
            end
            4'd10: begin
                cos_q = 16'shA57E; // -23170
                sin_q = 16'shA57E; // -23170
            end
            4'd11: begin
                cos_q = 16'shCF04; // -12540
                sin_q = 16'sh89BE; // -30274
            end
            4'd12: begin
                cos_q = 16'sh0000; //      0
                sin_q = 16'sh8000; // -32768
            end
            4'd13: begin
                cos_q = 16'sh30FC; //  12540
                sin_q = 16'sh89BE; // -30274
            end
            4'd14: begin
                cos_q = 16'sh5A82; //  23170
                sin_q = 16'shA57E; // -23170
            end
            4'd15: begin
                cos_q = 16'sh7642; //  30274
                sin_q = 16'shCF04; // -12540
            end
            default: begin
                cos_q = 16'sh7FFF;
                sin_q = 16'sh0000;
            end
        endcase
    end

endmodule