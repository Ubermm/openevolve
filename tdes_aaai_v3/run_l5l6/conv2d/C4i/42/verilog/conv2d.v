`timescale 1ns/1ps

module conv2d #(
    parameter DATA_W      = 8,
    parameter IMG_WIDTH   = 64,
    parameter KERNEL_SIZE = 3,
    parameter GAIN_W      = 4
) (
    input                           clk,
    input                           rst,
    input                           valid_in,
    input      [DATA_W-1:0]         pixel_in,
    output reg                      valid_out,
    output reg [DATA_W+GAIN_W-1:0]  pixel_out
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
        end
    endfunction

    localparam integer COUNT_W    = 32;
    localparam integer HIST_DEPTH = KERNEL_SIZE * IMG_WIDTH;
    localparam integer TAPS       = KERNEL_SIZE * KERNEL_SIZE;
    localparam integer COEFF_W    = 16;
    localparam integer ACC_W      = DATA_W + COEFF_W + CLOG2(TAPS + 1) + 2;
    localparam integer OUT_W      = DATA_W + GAIN_W;

    reg [DATA_W-1:0] history [0:HIST_DEPTH-1];
    reg [COUNT_W-1:0] pixel_count;

    wire [COUNT_W-1:0] count_next;
    wire [HIST_DEPTH*DATA_W-1:0] history_flat;
    wire [HIST_DEPTH*DATA_W-1:0] history_next_flat;

    wire window_valid;
    wire [COUNT_W-1:0] center_row;
    wire [COUNT_W-1:0] center_col;

    wire [TAPS*DATA_W-1:0] window_flat;
    wire [TAPS*COEFF_W-1:0] coeffs_flat;
    wire signed [ACC_W-1:0] accum_value;
    wire [OUT_W-1:0] cast_value;

    integer i;

    assign count_next = valid_in ? (pixel_count + {{(COUNT_W-1){1'b0}}, 1'b1}) : pixel_count;

    genvar gi;
    generate
        for (gi = 0; gi < HIST_DEPTH; gi = gi + 1) begin : GEN_HISTORY_FLAT
            assign history_flat[gi*DATA_W +: DATA_W] = history[gi];
        end

        for (gi = 0; gi < HIST_DEPTH; gi = gi + 1) begin : GEN_HISTORY_NEXT_FLAT
            if (gi == 0) begin : GEN_HEAD
                assign history_next_flat[gi*DATA_W +: DATA_W] =
                    valid_in ? pixel_in : history[gi];
            end else begin : GEN_BODY
                assign history_next_flat[gi*DATA_W +: DATA_W] =
                    valid_in ? history[gi-1] : history[gi];
            end
        end
    endgenerate

    conv2d_coord_gen #(
        .IMG_WIDTH(IMG_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .COUNT_W(COUNT_W)
    ) u_coord_gen (
        .pixel_count(count_next),
        .window_valid(window_valid),
        .center_row(center_row),
        .center_col(center_col)
    );

    conv2d_window_extract #(
        .DATA_W(DATA_W),
        .IMG_WIDTH(IMG_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .COUNT_W(COUNT_W)
    ) u_window_extract (
        .pixel_count(count_next),
        .center_row(center_row),
        .center_col(center_col),
        .history_flat(history_next_flat),
        .window_flat(window_flat)
    );

    conv2d_coeff_gen #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .COEFF_W(COEFF_W)
    ) u_coeff_gen (
        .coeffs_flat(coeffs_flat)
    );

    conv2d_dot_product #(
        .DATA_W(DATA_W),
        .KERNEL_SIZE(KERNEL_SIZE),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_dot_product (
        .window_flat(window_flat),
        .coeffs_flat(coeffs_flat),
        .accum(accum_value)
    );

    conv2d_output_cast #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W)
    ) u_output_cast (
        .accum(accum_value),
        .pixel_out(cast_value)
    );

    always @(posedge clk) begin
        if (rst) begin
            pixel_count <= {COUNT_W{1'b0}};
            valid_out   <= 1'b0;
            pixel_out   <= {OUT_W{1'b0}};
            for (i = 0; i < HIST_DEPTH; i = i + 1) begin
                history[i] <= {DATA_W{1'b0}};
            end
        end else begin
            valid_out <= valid_in & window_valid;
            pixel_out <= cast_value;

            if (valid_in) begin
                history[0] <= pixel_in;
                for (i = 1; i < HIST_DEPTH; i = i + 1) begin
                    history[i] <= history[i-1];
                end
                pixel_count <= pixel_count + {{(COUNT_W-1){1'b0}}, 1'b1};
            end
        end
    end

endmodule