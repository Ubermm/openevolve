`timescale 1ns/1ps

module conv2d_window_extract #(
    parameter DATA_W      = 8,
    parameter IMG_WIDTH   = 64,
    parameter KERNEL_SIZE = 3,
    parameter COUNT_W     = 32
) (
    input      [COUNT_W-1:0]                         pixel_count,
    input      [COUNT_W-1:0]                         center_row,
    input      [COUNT_W-1:0]                         center_col,
    input      [KERNEL_SIZE*IMG_WIDTH*DATA_W-1:0]    history_flat,
    output reg [KERNEL_SIZE*KERNEL_SIZE*DATA_W-1:0]  window_flat
);

    localparam integer RADIUS     = KERNEL_SIZE / 2;
    localparam integer HIST_DEPTH = KERNEL_SIZE * IMG_WIDTH;

    integer kr;
    integer kc;
    integer tap;

    integer center_row_i;
    integer center_col_i;
    integer pixel_count_i;

    integer nrow;
    integer ncol;

    integer latest_index;
    integer needed_index;
    integer age;

    always @* begin
        window_flat = {(KERNEL_SIZE*KERNEL_SIZE*DATA_W){1'b0}};

        center_row_i  = center_row;
        center_col_i  = center_col;
        pixel_count_i = pixel_count;

        if (pixel_count_i > 0) begin
            latest_index = pixel_count_i - 1;

            for (kr = 0; kr < KERNEL_SIZE; kr = kr + 1) begin
                for (kc = 0; kc < KERNEL_SIZE; kc = kc + 1) begin
                    tap = (kr * KERNEL_SIZE) + kc;

                    /*
                     * Use signed integer arithmetic here so that positions
                     * above or to the left of the image become negative
                     * instead of wrapping as unsigned values.
                     */
                    nrow = center_row_i + kr - RADIUS;
                    ncol = center_col_i + kc - RADIUS;

                    if ((nrow < 0) || (ncol < 0) || (ncol >= IMG_WIDTH)) begin
                        window_flat[tap*DATA_W +: DATA_W] = {DATA_W{1'b0}};
                    end else begin
                        needed_index = (nrow * IMG_WIDTH) + ncol;
                        age          = latest_index - needed_index;

                        if ((age >= 0) && (age < HIST_DEPTH)) begin
                            window_flat[tap*DATA_W +: DATA_W] =
                                history_flat[age*DATA_W +: DATA_W];
                        end else begin
                            window_flat[tap*DATA_W +: DATA_W] = {DATA_W{1'b0}};
                        end
                    end
                end
            end
        end
    end

endmodule