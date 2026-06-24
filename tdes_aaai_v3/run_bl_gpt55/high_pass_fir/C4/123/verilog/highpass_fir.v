`timescale 1ns/1ps

module highpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4
) (
    input                       clk,
    input                       rst,
    input                       valid_in,
    input      [DATA_W-1:0]     data_in,
    output reg                  valid_out,
    output reg [DATA_W+GAIN_W-1:0] data_out
);

    localparam OUT_W = DATA_W + GAIN_W;

    reg  [DATA_W*TAP_CNT-1:0] sample_shift_flat;
    wire [DATA_W*TAP_CNT-1:0] next_sample_shift_flat;
    wire signed [63:0]        mac_accum;
    wire [OUT_W-1:0]          scaled_result;

    highpass_fir_sample_insert #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) u_sample_insert (
        .samples_flat      (sample_shift_flat),
        .data_in           (data_in),
        .valid_in          (valid_in),
        .next_samples_flat (next_sample_shift_flat)
    );

    highpass_fir_mac101 #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) u_mac (
        .samples_flat (next_sample_shift_flat),
        .acc_out      (mac_accum)
    );

    highpass_fir_q15_scale #(
        .DATA_W(DATA_W),
        .GAIN_W(GAIN_W),
        .SHIFT(15)
    ) u_scale (
        .acc_in   (mac_accum),
        .data_out (scaled_result)
    );

    always @(posedge clk) begin
        if (rst) begin
            sample_shift_flat <= {DATA_W*TAP_CNT{1'b0}};
            valid_out         <= 1'b0;
            data_out          <= {OUT_W{1'b0}};
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                sample_shift_flat <= next_sample_shift_flat;
                data_out          <= scaled_result;
            end
        end
    end

endmodule