`timescale 1ns/1ps

module conv1d #(
    parameter DATA_W      = 8,
    parameter KERNEL_SIZE = 5,
    parameter GAIN_W      = 4
) (
    input                           clk,
    input                           rst,
    input                           valid_in,
    input      [DATA_W-1:0]         data_in,
    output                          valid_out,
    output     [DATA_W+GAIN_W-1:0]  data_out
);

    localparam OUT_W    = DATA_W + GAIN_W;
    localparam COEFF_W  = 16;
    localparam ACC_W    = DATA_W + COEFF_W + 8;
    localparam COUNT_W  = 4;

    reg  [DATA_W*KERNEL_SIZE-1:0] window_r;
    reg  [COUNT_W-1:0]            sample_count_r;
    reg                           valid_out_r;
    reg  [OUT_W-1:0]              data_out_r;

    wire [DATA_W*KERNEL_SIZE-1:0] next_window_w;
    wire [COEFF_W*KERNEL_SIZE-1:0] coeffs_w;
    wire signed [ACC_W-1:0]       mac_sum_w;
    wire [OUT_W-1:0]              cast_data_w;

    wire window_full_next;
    assign window_full_next = valid_in && (sample_count_r >= (KERNEL_SIZE-1));

    conv1d_window_next #(
        .DATA_W(DATA_W),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) u_window_next (
        .window_in(window_r),
        .sample_in(data_in),
        .shift_en(valid_in),
        .window_out(next_window_w)
    );

    conv1d_coeff_pack #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .COEFF_W(COEFF_W)
    ) u_coeff_pack (
        .coeffs_flat(coeffs_w)
    );

    conv1d_mac #(
        .DATA_W(DATA_W),
        .KERNEL_SIZE(KERNEL_SIZE),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_mac (
        .window_flat(next_window_w),
        .coeffs_flat(coeffs_w),
        .acc_out(mac_sum_w)
    );

    conv1d_output_cast #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W)
    ) u_output_cast (
        .acc_in(mac_sum_w),
        .data_out(cast_data_w)
    );

    assign valid_out = valid_out_r;
    assign data_out  = data_out_r;

    always @(posedge clk) begin
        if (rst) begin
            window_r       <= {DATA_W*KERNEL_SIZE{1'b0}};
            sample_count_r <= {COUNT_W{1'b0}};
            valid_out_r    <= 1'b0;
            data_out_r     <= {OUT_W{1'b0}};
        end else begin
            valid_out_r <= 1'b0;

            if (valid_in) begin
                window_r    <= next_window_w;
                data_out_r  <= cast_data_w;
                valid_out_r <= window_full_next;

                if (sample_count_r < KERNEL_SIZE[COUNT_W-1:0])
                    sample_count_r <= sample_count_r + {{(COUNT_W-1){1'b0}}, 1'b1};
                else
                    sample_count_r <= sample_count_r;
            end
        end
    end

endmodule