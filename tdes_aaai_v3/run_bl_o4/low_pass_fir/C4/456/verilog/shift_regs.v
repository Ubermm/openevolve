`timescale 1ns/1ps
module shift_regs #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101
) (
    input                        clk,
    input                        rst,
    input                        valid_in,
    input  [DATA_W-1:0]          data_in,
    output [DATA_W*TAP_CNT-1:0]  taps
);

    // Internal shift‐register array
    reg [DATA_W-1:0] taps_array [0:TAP_CNT-1];
    integer i;

    // Shift‐register behavior: synchronous reset, shift on valid_in
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < TAP_CNT; i = i + 1)
                taps_array[i] <= {DATA_W{1'b0}};
        end else if (valid_in) begin
            taps_array[0] <= data_in;
            for (i = 1; i < TAP_CNT; i = i + 1)
                taps_array[i] <= taps_array[i-1];
        end
    end

    // Pack the array into a flat bus (MSB = oldest tap)
    genvar gi;
    generate
        for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : FLATTEN
            // taps[MSB:LSB] = { tap[TAP_CNT-1], ..., tap[0] }
            assign taps[(TAP_CNT-gi)*DATA_W-1 -: DATA_W] = taps_array[gi];
        end
    endgenerate

endmodule