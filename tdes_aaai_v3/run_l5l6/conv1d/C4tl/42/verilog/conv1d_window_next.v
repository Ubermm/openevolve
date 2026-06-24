`timescale 1ns/1ps

module conv1d_window_next #(
    parameter DATA_W      = 8,
    parameter KERNEL_SIZE = 5
) (
    input  [KERNEL_SIZE*DATA_W-1:0] current_window,
    input  [DATA_W-1:0]             data_in,
    input                           valid_in,
    output reg [KERNEL_SIZE*DATA_W-1:0] next_window
);

    integer i;

    always @* begin
        /*
         * Default behavior is hold.
         * This is important because the surrounding window register should only
         * advance when a real input sample is accepted.
         */
        next_window = current_window;

        if (valid_in) begin
            /*
             * Tap 0 is the newest sample.
             */
            next_window[0 +: DATA_W] = data_in;

            /*
             * Shift previous samples toward older tap positions.
             * The previous oldest tap, tap KERNEL_SIZE-1, is discarded.
             */
            for (i = 1; i < KERNEL_SIZE; i = i + 1) begin
                next_window[i*DATA_W +: DATA_W] =
                    current_window[(i-1)*DATA_W +: DATA_W];
            end
        end
    end

endmodule