`timescale 1ns/1ps

module conv2d #(
    parameter DATA_W      = 8,
    parameter IMG_WIDTH   = 64,
    parameter KERNEL_SIZE = 3,
    parameter GAIN_W      = 4
) (
    input                          clk,
    input                          rst,
    input                          valid_in,
    input      [DATA_W-1:0]        pixel_in,
    output reg                     valid_out,
    output reg [DATA_W+GAIN_W-1:0] pixel_out
);

    function integer CLOG2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            CLOG2 = 0;
            while (v > 0) begin
                v = v >> 1;
                CLOG2 = CLOG2 + 1;
            end
            if (CLOG2 == 0)
                CLOG2 = 1;
        end
    endfunction

    localparam OUT_W   = DATA_W + GAIN_W;
    localparam COEFF_W = 16;
    localparam K2      = KERNEL_SIZE * KERNEL_SIZE;
    localparam LB      = KERNEL_SIZE - 1;
    localparam COL_W   = CLOG2(IMG_WIDTH);
    localparam ACC_W   = DATA_W + COEFF_W + CLOG2(K2) + 4;

    reg  [DATA_W-1:0] linebuf [0:LB*IMG_WIDTH-1];
    reg  [DATA_W-1:0] hshift  [0:K2-1];

    reg  [COL_W-1:0]  col_count;
    reg  [31:0]       row_count;

    wire [DATA_W*KERNEL_SIZE-1:0] taps_bus;
    wire [DATA_W*K2-1:0]          shift_current_bus;
    wire [DATA_W*K2-1:0]          shift_next_bus;
    wire [DATA_W*K2-1:0]          window_bus;
    wire [COEFF_W*K2-1:0]         coeff_bus;
    wire signed [ACC_W-1:0]       acc_sum;
    wire [OUT_W-1:0]              cast_out;
    wire                          valid_region;
    wire [31:0]                   col_count_32;

    genvar gi;

    assign taps_bus[0 +: DATA_W] = pixel_in;

    generate
        for (gi = 1; gi < KERNEL_SIZE; gi = gi + 1) begin : GEN_TAPS
            assign taps_bus[gi*DATA_W +: DATA_W] =
                linebuf[(gi-1)*IMG_WIDTH + col_count];
        end
    endgenerate

    generate
        for (gi = 0; gi < K2; gi = gi + 1) begin : GEN_SHIFT_BUS
            assign shift_current_bus[gi*DATA_W +: DATA_W] = hshift[gi];
        end
    endgenerate

    assign col_count_32 = {{(32-COL_W){1'b0}}, col_count};

    conv2d_window_update #(
        .DATA_W(DATA_W),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) u_window_update (
        .line_start(col_count == {COL_W{1'b0}}),
        .taps_in(taps_bus),
        .shift_current(shift_current_bus),
        .shift_next(shift_next_bus),
        .window_flat(window_bus)
    );

    conv2d_valid_region #(
        .KERNEL_SIZE(KERNEL_SIZE)
    ) u_valid_region (
        .valid_in(valid_in),
        .row_count(row_count),
        .col_count(col_count_32),
        .valid_out(valid_region)
    );

    conv2d_coeff_rom #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .COEFF_W(COEFF_W)
    ) u_coeff_rom (
        .coeffs(coeff_bus)
    );

    conv2d_dot_product #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .KERNEL_SIZE(KERNEL_SIZE),
        .ACC_W(ACC_W)
    ) u_dot_product (
        .pixels(window_bus),
        .coeffs(coeff_bus),
        .sum(acc_sum)
    );

    conv2d_output_cast #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W)
    ) u_output_cast (
        .sum_in(acc_sum),
        .pixel_out(cast_out)
    );

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_count <= {COL_W{1'b0}};
            row_count <= 32'd0;
            valid_out <= 1'b0;
            pixel_out <= {OUT_W{1'b0}};

            for (i = 0; i < LB*IMG_WIDTH; i = i + 1)
                linebuf[i] <= {DATA_W{1'b0}};

            for (i = 0; i < K2; i = i + 1)
                hshift[i] <= {DATA_W{1'b0}};
        end else begin
            valid_out <= 1'b0;

            if (valid_in) begin
                valid_out <= valid_region;
                if (valid_region)
                    pixel_out <= cast_out;
                else
                    pixel_out <= {OUT_W{1'b0}};

                for (i = 0; i < K2; i = i + 1)
                    hshift[i] <= shift_next_bus[i*DATA_W +: DATA_W];

                linebuf[col_count] <= pixel_in;
                for (i = 1; i < LB; i = i + 1)
                    linebuf[i*IMG_WIDTH + col_count] <=
                        linebuf[(i-1)*IMG_WIDTH + col_count];

                if (col_count == IMG_WIDTH-1) begin
                    col_count <= {COL_W{1'b0}};
                    row_count <= row_count + 32'd1;
                end else begin
                    col_count <= col_count + {{(COL_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

endmodule