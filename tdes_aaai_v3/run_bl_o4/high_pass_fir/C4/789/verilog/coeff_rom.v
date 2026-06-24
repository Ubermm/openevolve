module coeff_rom #(
    parameter TAP_CNT  = 101,
    parameter COEFF_W  = 16
) (
    input  wire [6:0]                   idx,
    output reg signed [COEFF_W-1:0]     coeff
);

    always @(*) begin
        case (idx)
            7'd0:   coeff = 16'sd0;
            7'd1:   coeff = 16'sd10;
            7'd2:   coeff = 16'sd17;
            7'd3:   coeff = 16'sd19;
            7'd4:   coeff = 16'sd13;
            7'd5:   coeff = 16'sd0;
            7'd6:   coeff = 16'sd-16;
            7'd7:   coeff = 16'sd-29;
            7'd8:   coeff = 16'sd-32;
            7'd9:   coeff = 16'sd-23;
            7'd10:  coeff = 16'sd0;
            7'd11:  coeff = 16'sd29;
            7'd12:  coeff = 16'sd53;
            7'd13:  coeff = 16'sd60;
            7'd14:  coeff = 16'sd42;
            7'd15:  coeff = 16'sd0;
            7'd16:  coeff = 16'sd-53;
            7'd17:  coeff = 16'sd-96;
            7'd18:  coeff = 16'sd-107;
            7'd19:  coeff = 16'sd-73;
            7'd20:  coeff = 16'sd0;
            7'd21:  coeff = 16'sd90;
            7'd22:  coeff = 16'sd161;
            7'd23:  coeff = 16'sd177;
            7'd24:  coeff = 16'sd121;
            7'd25:  coeff = 16'sd0;
            7'd26:  coeff = 16'sd-145;
            7'd27:  coeff = 16'sd-258;
            7'd28:  coeff = 16'sd-282;
            7'd29:  coeff = 16'sd-191;
            7'd30:  coeff = 16'sd0;
            7'd31:  coeff = 16'sd229;
            7'd32:  coeff = 16'sd406;
            7'd33:  coeff = 16'sd444;
            7'd34:  coeff = 16'sd301;
            7'd35:  coeff = 16'sd0;
            7'd36:  coeff = 16'sd-365;
            7'd37:  coeff = 16'sd-652;
            7'd38:  coeff = 16'sd-724;
            7'd39:  coeff = 16'sd-499;
            7'd40:  coeff = 16'sd0;
            7'd41:  coeff = 16'sd633;
            7'd42:  coeff = 16'sd1170;
            7'd43:  coeff = 16'sd1355;
            7'd44:  coeff = 16'sd989;
            7'd45:  coeff = 16'sd0;
            7'd46:  coeff = 16'sd-1511;
            7'd47:  coeff = 16'sd-3280;
            7'd48:  coeff = 16'sd-4943;
            7'd49:  coeff = 16'sd-6126;
            7'd50:  coeff = 16'sd26219;
            7'd51:  coeff = 16'sd-6126;
            7'd52:  coeff = 16'sd-4943;
            7'd53:  coeff = 16'sd-3280;
            7'd54:  coeff = 16'sd-1511;
            7'd55:  coeff = 16'sd0;
            7'd56:  coeff = 16'sd989;
            7'd57:  coeff = 16'sd1355;
            7'd58:  coeff = 16'sd1170;
            7'd59:  coeff = 16'sd633;
            7'd60:  coeff = 16'sd0;
            7'd61:  coeff = 16'sd-499;
            7'd62:  coeff = 16'sd-724;
            7'd63:  coeff = 16'sd-652;
            7'd64:  coeff = 16'sd-365;
            7'd65:  coeff = 16'sd0;
            7'd66:  coeff = 16'sd301;
            7'd67:  coeff = 16'sd444;
            7'd68:  coeff = 16'sd406;
            7'd69:  coeff = 16'sd229;
            7'd70:  coeff = 16'sd0;
            7'd71:  coeff = 16'sd-191;
            7'd72:  coeff = 16'sd-282;
            7'd73:  coeff = 16'sd-258;
            7'd74:  coeff = 16'sd-145;
            7'd75:  coeff = 16'sd0;
            7'd76:  coeff = 16'sd121;
            7'd77:  coeff = 16'sd177;
            7'd78:  coeff = 16'sd161;
            7'd79:  coeff = 16'sd90;
            7'd80:  coeff = 16'sd0;
            7'd81:  coeff = 16'sd-73;
            7'd82:  coeff = 16'sd-107;
            7'd83:  coeff = 16'sd-96;
            7'd84:  coeff = 16'sd-53;
            7'd85:  coeff = 16'sd0;
            7'd86:  coeff = 16'sd42;
            7'd87:  coeff = 16'sd60;
            7'd88:  coeff = 16'sd53;
            7'd89:  coeff = 16'sd29;
            7'd90:  coeff = 16'sd0;
            7'd91:  coeff = 16'sd-23;
            7'd92:  coeff = 16'sd-32;
            7'd93:  coeff = 16'sd-29;
            7'd94:  coeff = 16'sd-16;
            7'd95:  coeff = 16'sd0;
            7'd96:  coeff = 16'sd13;
            7'd97:  coeff = 16'sd19;
            7'd98:  coeff = 16'sd17;
            7'd99:  coeff = 16'sd10;
            7'd100: coeff = 16'sd0;
            default: coeff = 16'sd0;
        endcase
    end

endmodule