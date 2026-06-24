`timescale 1ns/1ps

module conv2d_window_update #(
    parameter DATA_W      = 8,
    parameter KERNEL_SIZE = 3
) (
    input                                      line_start,
    input      [DATA_W*KERNEL_SIZE-1:0]       taps_in,
    input      [DATA_W*KERNEL_SIZE*KERNEL_SIZE-1:0] shift_current,
    output reg [DATA_W*KERNEL_SIZE*KERNEL_SIZE-1:0] shift_next,
    output reg [DATA_W*KERNEL_SIZE*KERNEL_SIZE-1:0] window_flat
);

    integer v;
    integer h;
    integer kr;
    integer kc;
    integer src_v;
    integer src_h;

    always @* begin
        /*
         * Horizontal shift state layout:
         *
         *   shift[row][0]             = newest/current column tap
         *   shift[row][KERNEL_SIZE-1] = oldest column tap
         *
         * At the start of a new image line, stale pixels from the previous
         * line must be discarded so they do not wrap around as left neighbors.
         */
        shift_next = {DATA_W*KERNEL_SIZE*KERNEL_SIZE{1'b0}};

        for (v = 0; v < KERNEL_SIZE; v = v + 1) begin
            /* Insert current vertical tap as newest horizontal sample. */
            shift_next[(v*KERNEL_SIZE + 0)*DATA_W +: DATA_W] =
                taps_in[v*DATA_W +: DATA_W];

            /* Shift older samples, or inject zero left-padding at line start. */
            for (h = 1; h < KERNEL_SIZE; h = h + 1) begin
                if (line_start) begin
                    shift_next[(v*KERNEL_SIZE + h)*DATA_W +: DATA_W] =
                        {DATA_W{1'b0}};
                end else begin
                    shift_next[(v*KERNEL_SIZE + h)*DATA_W +: DATA_W] =
                        shift_current[(v*KERNEL_SIZE + h - 1)*DATA_W +: DATA_W];
                end
            end
        end

        /*
         * Format the updated shift register as a spatial KxK window in
         * row-major order:
         *
         *   window_flat[0] = top-left
         *   window_flat[KERNEL_SIZE*KERNEL_SIZE-1] = bottom-right
         *
         * The tap/shift storage is newest-first, so reverse both vertical and
         * horizontal axes when producing the convolution window.
         */
        window_flat = {DATA_W*KERNEL_SIZE*KERNEL_SIZE{1'b0}};

        for (kr = 0; kr < KERNEL_SIZE; kr = kr + 1) begin
            for (kc = 0; kc < KERNEL_SIZE; kc = kc + 1) begin
                src_v = KERNEL_SIZE - 1 - kr;
                src_h = KERNEL_SIZE - 1 - kc;

                window_flat[(kr*KERNEL_SIZE + kc)*DATA_W +: DATA_W] =
                    shift_next[(src_v*KERNEL_SIZE + src_h)*DATA_W +: DATA_W];
            end
        end
    end

endmodule