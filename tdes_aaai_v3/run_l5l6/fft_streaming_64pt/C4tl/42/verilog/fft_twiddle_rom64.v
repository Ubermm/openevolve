`timescale 1ns/1ps

module fft_twiddle_rom64 #(
    parameter POINTS = 64,
    parameter TW_W   = 16
) (
    input  [$clog2(POINTS)-1:0] addr,
    output reg signed [TW_W-1:0] tw_real,
    output reg signed [TW_W-1:0] tw_imag
);

    real pi;
    real angle;
    real scale;
    integer rtmp;
    integer itmp;

    always @* begin
        pi    = 3.14159265358979323846;
        scale = (1 << (TW_W-1)) - 1;
        angle = -2.0 * pi * addr / POINTS;

        rtmp = $rtoi($cos(angle) * scale);
        itmp = $rtoi($sin(angle) * scale);

        tw_real = rtmp[TW_W-1:0];
        tw_imag = itmp[TW_W-1:0];
    end

endmodule