`timescale 1ns/1ps

module conv2d_valid_region #(
    parameter KERNEL_SIZE = 3
) (
    input        valid_in,
    input [31:0] row_count,
    input [31:0] col_count,
    output       valid_out
);

    /*
     * For an odd-sized stencil, the radius is the number of rows/columns
     * that must have been buffered before the centered convolution window
     * is considered valid.
     *
     * Example:
     *   KERNEL_SIZE = 3 -> RADIUS = 1
     *   KERNEL_SIZE = 5 -> RADIUS = 2
     *   KERNEL_SIZE = 7 -> RADIUS = 3
     */
    localparam [31:0] RADIUS = KERNEL_SIZE / 2;

    assign valid_out = valid_in &&
                       (row_count >= RADIUS) &&
                       (col_count >= RADIUS);

endmodule