module fir_mac #(
    parameter integer DATA_W  = 20,
    parameter integer TAP_CNT = 101
) (
    input  wire [DATA_W*TAP_CNT-1:0] data_in,
    output reg signed [63:0]        mac_out
);

    // Hard‐coded 16‐bit signed coefficients for taps 0..100
    localparam signed [15:0] COEFFS [0:TAP_CNT-1] = '{
         16,   10,    6,    2,    0,    1,    5,   13,   26,   42,
         59,   77,   90,   97,   93,   77,   47,    5,  -45,  -99,
       -149, -187, -207, -204, -178, -132,  -73,  -14,   31,   46,
         16,  -67, -208, -403, -638, -891,-1134,-1333,-1455,-1471,
      -1359,-1111, -730, -235,  341,  955, 1555, 2091, 2513, 2784,
       2877, 2784, 2513, 2091, 1555,  955,  341, -235, -730,-1111,
      -1359,-1471,-1455,-1333,-1134, -891, -638, -403, -208,  -67,
         16,   46,   31,  -14,  -73, -132, -178, -204, -207, -187,
       -149,  -99,  -45,    5,   47,   77,   93,   97,   90,   77,
         59,   42,   26,   13,    5,    1,    0,    2,    6,   10,
         16
    };

    integer i;
    always @* begin
        mac_out = 64'sd0;
        for (i = 0; i < TAP_CNT; i = i + 1) begin
            // slice out the i-th DATA_W-bit signed sample
            mac_out = mac_out
                    + $signed(data_in[i*DATA_W +: DATA_W])
                    * COEFFS[i];
        end
    end

endmodule