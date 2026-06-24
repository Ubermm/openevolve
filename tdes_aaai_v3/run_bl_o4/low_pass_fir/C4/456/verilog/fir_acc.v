module fir_acc #(
    parameter integer DATA_W  = 20,
    parameter integer TAP_CNT = 101,
    parameter integer COEFF_W = 16,
    parameter integer ACC_W   = 64,
    parameter integer GAIN_W  = 4
) (
    input  wire signed [DATA_W-1:0] taps [0:TAP_CNT-1],
    output reg  signed [DATA_W+GAIN_W-1:0] data_out
);

    integer i;
    reg signed [ACC_W-1:0] acc;

    // Hard-coded 101-tap symmetric FIR coefficients (scale = 2^15)
    function automatic signed [COEFF_W-1:0] get_coeff;
        input integer idx;
        begin
            case (idx)
                0:   get_coeff =     0;
                1:   get_coeff =    -2;
                2:   get_coeff =    -5;
                3:   get_coeff =    -7;
                4:   get_coeff =   -10;
                5:   get_coeff =   -14;
                6:   get_coeff =   -18;
                7:   get_coeff =   -23;
                8:   get_coeff =   -29;
                9:   get_coeff =   -35;
               10:   get_coeff =   -41;
               11:   get_coeff =   -49;
               12:   get_coeff =   -56;
               13:   get_coeff =   -63;
               14:   get_coeff =   -70;
               15:   get_coeff =   -76;
               16:   get_coeff =   -81;
               17:   get_coeff =   -85;
               18:   get_coeff =   -86;
               19:   get_coeff =   -85;
               20:   get_coeff =   -81;
               21:   get_coeff =   -73;
               22:   get_coeff =   -62;
               23:   get_coeff =   -46;
               24:   get_coeff =   -26;
               25:   get_coeff =     0;
               26:   get_coeff =    31;
               27:   get_coeff =    67;
               28:   get_coeff =   109;
               29:   get_coeff =   156;
               30:   get_coeff =   208;
               31:   get_coeff =   266;
               32:   get_coeff =   327;
               33:   get_coeff =   393;
               34:   get_coeff =   462;
               35:   get_coeff =   534;
               36:   get_coeff =   607;
               37:   get_coeff =   682;
               38:   get_coeff =   756;
               39:   get_coeff =   830;
               40:   get_coeff =   901;
               41:   get_coeff =   970;
               42:   get_coeff =  1034;
               43:   get_coeff =  1094;
               44:   get_coeff =  1147;
               45:   get_coeff =  1194;
               46:   get_coeff =  1233;
               47:   get_coeff =  1265;
               48:   get_coeff =  1287;
               49:   get_coeff =  1301;
               50:   get_coeff =  1306;
               51:   get_coeff =  1301;
               52:   get_coeff =  1287;
               53:   get_coeff =  1265;
               54:   get_coeff =  1233;
               55:   get_coeff =  1194;
               56:   get_coeff =  1147;
               57:   get_coeff =  1094;
               58:   get_coeff =  1034;
               59:   get_coeff =   970;
               60:   get_coeff =   901;
               61:   get_coeff =   830;
               62:   get_coeff =   756;
               63:   get_coeff =   682;
               64:   get_coeff =   607;
               65:   get_coeff =   534;
               66:   get_coeff =   462;
               67:   get_coeff =   393;
               68:   get_coeff =   327;
               69:   get_coeff =   266;
               70:   get_coeff =   208;
               71:   get_coeff =   156;
               72:   get_coeff =   109;
               73:   get_coeff =    67;
               74:   get_coeff =    31;
               75:   get_coeff =     0;
               76:   get_coeff =   -26;
               77:   get_coeff =   -46;
               78:   get_coeff =   -62;
               79:   get_coeff =   -73;
               80:   get_coeff =   -81;
               81:   get_coeff =   -85;
               82:   get_coeff =   -86;
               83:   get_coeff =   -85;
               84:   get_coeff =   -81;
               85:   get_coeff =   -76;
               86:   get_coeff =   -70;
               87:   get_coeff =   -63;
               88:   get_coeff =   -56;
               89:   get_coeff =   -49;
               90:   get_coeff =   -41;
               91:   get_coeff =   -35;
               92:   get_coeff =   -29;
               93:   get_coeff =   -23;
               94:   get_coeff =   -18;
               95:   get_coeff =   -14;
               96:   get_coeff =   -10;
               97:   get_coeff =    -7;
               98:   get_coeff =    -5;
               99:   get_coeff =    -2;
              100:   get_coeff =     0;
              default: get_coeff =     0;
            endcase
        end
    endfunction

    // Combinational MAC and scaling
    always @* begin
        acc = 'sd0;
        for (i = 0; i < TAP_CNT; i = i + 1) begin
            acc = acc + $signed(taps[i]) * $signed(get_coeff(i));
        end
        // Remove coefficient scale (2^15) via arithmetic shift
        data_out = (acc >>> (COEFF_W-1));
    end

endmodule