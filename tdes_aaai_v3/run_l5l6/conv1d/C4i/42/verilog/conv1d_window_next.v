`timescale 1ns/1ps

module conv1d_window_next #(
    parameter DATA_W      = 8,
    parameter KERNEL_SIZE = 5
) (
    input  [DATA_W*KERNEL_SIZE-1:0] window_in,
    input  [DATA_W-1:0]             sample_in,
    input                           shift_en,
    output reg [DATA_W*KERNEL_SIZE-1:0] window_out
);

    integer i;

    always @* begin
        // Default: hold current window state.
        window_out = window_in;

        // On shift enable, advance the sliding window and insert the new sample.
        if (shift_en) begin
            for (i = 0; i < KERNEL_SIZE-1; i = i + 1) begin
                window_out[i*DATA_W +: DATA_W] =
                    window_in[(i+1)*DATA_W +: DATA_W];
            end

            window_out[(KERNEL_SIZE-1)*DATA_W +: DATA_W] = sample_in;
        end
    end

endmodule