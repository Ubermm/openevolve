`timescale 1ns/1ps

module conv2d_coord_gen #(
    parameter IMG_WIDTH   = 64,
    parameter KERNEL_SIZE = 3,
    parameter COUNT_W     = 32
) (
    input      [COUNT_W-1:0] pixel_count,
    output reg               window_valid,
    output reg [COUNT_W-1:0] center_row,
    output reg [COUNT_W-1:0] center_col
);

    localparam integer RADIUS = KERNEL_SIZE / 2;
    localparam [COUNT_W-1:0] DELAY_COUNT =
        (RADIUS * IMG_WIDTH) + RADIUS;

    reg [COUNT_W-1:0] center_index;

    always @* begin
        window_valid = 1'b0;
        center_index = {COUNT_W{1'b0}};
        center_row   = {COUNT_W{1'b0}};
        center_col   = {COUNT_W{1'b0}};

        if (pixel_count > DELAY_COUNT) begin
            window_valid = 1'b1;

            /*
             * pixel_count is the number of accepted pixels.
             * The corresponding zero-based input index is pixel_count - 1.
             * The stencil center is delayed by DELAY_COUNT pixels.
             */
            center_index = pixel_count - DELAY_COUNT - 1'b1;

            center_row = center_index / IMG_WIDTH;
            center_col = center_index % IMG_WIDTH;
        end
    end

endmodule