`timescale 1ns/1ps

module fft16_twiddle_rom #(
    parameter COEFF_W = 16,
    parameter ADDR_W  = 4
) (
    input  [ADDR_W-1:0] tw_addr,
    output signed [COEFF_W-1:0] cos_q15,
    output signed [COEFF_W-1:0] sin_q15
);

    reg signed [15:0] cos_rom;
    reg signed [15:0] sin_rom;

    always @* begin
        case (tw_addr)
            4'd0:  begin cos_rom = 16'sh7FFF; sin_rom = 16'sh0000; end //  32767,      0
            4'd1:  begin cos_rom = 16'sh7642; sin_rom = 16'sh30FC; end //  30274,  12540
            4'd2:  begin cos_rom = 16'sh5A82; sin_rom = 16'sh5A82; end //  23170,  23170
            4'd3:  begin cos_rom = 16'sh30FC; sin_rom = 16'sh7642; end //  12540,  30274
            4'd4:  begin cos_rom = 16'sh0000; sin_rom = 16'sh7FFF; end //      0,  32767
            4'd5:  begin cos_rom = 16'shCF04; sin_rom = 16'sh7642; end // -12540,  30274
            4'd6:  begin cos_rom = 16'shA57E; sin_rom = 16'sh5A82; end // -23170,  23170
            4'd7:  begin cos_rom = 16'sh89BE; sin_rom = 16'sh30FC; end // -30274,  12540
            4'd8:  begin cos_rom = 16'sh8000; sin_rom = 16'sh0000; end // -32768,      0
            4'd9:  begin cos_rom = 16'sh89BE; sin_rom = 16'shCF04; end // -30274, -12540
            4'd10: begin cos_rom = 16'shA57E; sin_rom = 16'shA57E; end // -23170, -23170
            4'd11: begin cos_rom = 16'shCF04; sin_rom = 16'sh89BE; end // -12540, -30274
            4'd12: begin cos_rom = 16'sh0000; sin_rom = 16'sh8000; end //      0, -32768
            4'd13: begin cos_rom = 16'sh30FC; sin_rom = 16'sh89BE; end //  12540, -30274
            4'd14: begin cos_rom = 16'sh5A82; sin_rom = 16'shA57E; end //  23170, -23170
            4'd15: begin cos_rom = 16'sh7642; sin_rom = 16'shCF04; end //  30274, -12540
            default: begin cos_rom = 16'sh0000; sin_rom = 16'sh0000; end
        endcase
    end

    assign cos_q15 = cos_rom;
    assign sin_q15 = sin_rom;

endmodule