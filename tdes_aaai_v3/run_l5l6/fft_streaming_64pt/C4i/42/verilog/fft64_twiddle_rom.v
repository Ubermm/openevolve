`timescale 1ns/1ps

module fft64_twiddle_rom #(
    parameter TW_W = 16
) (
    input  [5:0] addr,
    output reg signed [TW_W-1:0] tw_re,
    output reg signed [TW_W-1:0] tw_im
);

    always @* begin
        case (addr)
            6'd0 : begin tw_re =  16'sd32767; tw_im =      16'sd0;     end
            6'd1 : begin tw_re =  16'sd32610; tw_im =  -16'sd3212;  end
            6'd2 : begin tw_re =  16'sd32138; tw_im =  -16'sd6393;  end
            6'd3 : begin tw_re =  16'sd31357; tw_im =  -16'sd9512;  end
            6'd4 : begin tw_re =  16'sd30274; tw_im = -16'sd12540;  end
            6'd5 : begin tw_re =  16'sd28899; tw_im = -16'sd15447;  end
            6'd6 : begin tw_re =  16'sd27245; tw_im = -16'sd18205;  end
            6'd7 : begin tw_re =  16'sd25330; tw_im = -16'sd20787;  end
            6'd8 : begin tw_re =  16'sd23170; tw_im = -16'sd23170;  end
            6'd9 : begin tw_re =  16'sd20787; tw_im = -16'sd25330;  end
            6'd10: begin tw_re =  16'sd18205; tw_im = -16'sd27245;  end
            6'd11: begin tw_re =  16'sd15447; tw_im = -16'sd28899;  end
            6'd12: begin tw_re =  16'sd12540; tw_im = -16'sd30274;  end
            6'd13: begin tw_re =   16'sd9512; tw_im = -16'sd31357;  end
            6'd14: begin tw_re =   16'sd6393; tw_im = -16'sd32138;  end
            6'd15: begin tw_re =   16'sd3212; tw_im = -16'sd32610;  end
            6'd16: begin tw_re =      16'sd0; tw_im = -16'sd32767;  end
            6'd17: begin tw_re =  -16'sd3212; tw_im = -16'sd32610;  end
            6'd18: begin tw_re =  -16'sd6393; tw_im = -16'sd32138;  end
            6'd19: begin tw_re =  -16'sd9512; tw_im = -16'sd31357;  end
            6'd20: begin tw_re = -16'sd12540; tw_im = -16'sd30274;  end
            6'd21: begin tw_re = -16'sd15447; tw_im = -16'sd28899;  end
            6'd22: begin tw_re = -16'sd18205; tw_im = -16'sd27245;  end
            6'd23: begin tw_re = -16'sd20787; tw_im = -16'sd25330;  end
            6'd24: begin tw_re = -16'sd23170; tw_im = -16'sd23170;  end
            6'd25: begin tw_re = -16'sd25330; tw_im = -16'sd20787;  end
            6'd26: begin tw_re = -16'sd27245; tw_im = -16'sd18205;  end
            6'd27: begin tw_re = -16'sd28899; tw_im = -16'sd15447;  end
            6'd28: begin tw_re = -16'sd30274; tw_im = -16'sd12540;  end
            6'd29: begin tw_re = -16'sd31357; tw_im =  -16'sd9512;  end
            6'd30: begin tw_re = -16'sd32138; tw_im =  -16'sd6393;  end
            6'd31: begin tw_re = -16'sd32610; tw_im =  -16'sd3212;  end
            6'd32: begin tw_re = -16'sd32767; tw_im =      16'sd0;   end
            6'd33: begin tw_re = -16'sd32610; tw_im =   16'sd3212;  end
            6'd34: begin tw_re = -16'sd32138; tw_im =   16'sd6393;  end
            6'd35: begin tw_re = -16'sd31357; tw_im =   16'sd9512;  end
            6'd36: begin tw_re = -16'sd30274; tw_im =  16'sd12540;  end
            6'd37: begin tw_re = -16'sd28899; tw_im =  16'sd15447;  end
            6'd38: begin tw_re = -16'sd27245; tw_im =  16'sd18205;  end
            6'd39: begin tw_re = -16'sd25330; tw_im =  16'sd20787;  end
            6'd40: begin tw_re = -16'sd23170; tw_im =  16'sd23170;  end
            6'd41: begin tw_re = -16'sd20787; tw_im =  16'sd25330;  end
            6'd42: begin tw_re = -16'sd18205; tw_im =  16'sd27245;  end
            6'd43: begin tw_re = -16'sd15447; tw_im =  16'sd28899;  end
            6'd44: begin tw_re = -16'sd12540; tw_im =  16'sd30274;  end
            6'd45: begin tw_re =  -16'sd9512; tw_im =  16'sd31357;  end
            6'd46: begin tw_re =  -16'sd6393; tw_im =  16'sd32138;  end
            6'd47: begin tw_re =  -16'sd3212; tw_im =  16'sd32610;  end
            6'd48: begin tw_re =      16'sd0; tw_im =  16'sd32767;  end
            6'd49: begin tw_re =   16'sd3212; tw_im =  16'sd32610;  end
            6'd50: begin tw_re =   16'sd6393; tw_im =  16'sd32138;  end
            6'd51: begin tw_re =   16'sd9512; tw_im =  16'sd31357;  end
            6'd52: begin tw_re =  16'sd12540; tw_im =  16'sd30274;  end
            6'd53: begin tw_re =  16'sd15447; tw_im =  16'sd28899;  end
            6'd54: begin tw_re =  16'sd18205; tw_im =  16'sd27245;  end
            6'd55: begin tw_re =  16'sd20787; tw_im =  16'sd25330;  end
            6'd56: begin tw_re =  16'sd23170; tw_im =  16'sd23170;  end
            6'd57: begin tw_re =  16'sd25330; tw_im =  16'sd20787;  end
            6'd58: begin tw_re =  16'sd27245; tw_im =  16'sd18205;  end
            6'd59: begin tw_re =  16'sd28899; tw_im =  16'sd15447;  end
            6'd60: begin tw_re =  16'sd30274; tw_im =  16'sd12540;  end
            6'd61: begin tw_re =  16'sd31357; tw_im =   16'sd9512;  end
            6'd62: begin tw_re =  16'sd32138; tw_im =   16'sd6393;  end
            6'd63: begin tw_re =  16'sd32610; tw_im =   16'sd3212;  end

            default: begin
                tw_re = 16'sd32767;
                tw_im = 16'sd0;
            end
        endcase
    end

endmodule