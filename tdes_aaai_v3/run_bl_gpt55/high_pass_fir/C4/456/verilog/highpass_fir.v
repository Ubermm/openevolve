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
    output                      valid_out,
    output     [DATA_W+GAIN_W-1:0] data_out
);

    localparam OUT_W   = DATA_W + GAIN_W;
    localparam COEFF_W = 16;
    localparam ACC_W   = 64;

    reg  [DATA_W*TAP_CNT-1:0] delay_line_r;
    wire [DATA_W*TAP_CNT-1:0] delay_line_next;

    wire [COEFF_W*TAP_CNT-1:0] coeffs_flat;
    wire signed [ACC_W-1:0]    acc_comb;
    wire signed [OUT_W-1:0]    quantized_comb;

    reg                        valid_out_r;
    reg signed [OUT_W-1:0]     data_out_r;

    highpass_fir_delay_next #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) u_delay_next (
        .valid_in(valid_in),
        .data_in(data_in),
        .delay_line_in(delay_line_r),
        .delay_line_out(delay_line_next)
    );

    highpass_fir_coeffs #(
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W)
    ) u_coeffs (
        .coeffs_flat(coeffs_flat)
    );

    highpass_fir_mac #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_mac (
        .samples_flat(delay_line_next),
        .coeffs_flat(coeffs_flat),
        .acc_out(acc_comb)
    );

    highpass_fir_quantize #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W),
        .SHIFT(15)
    ) u_quantize (
        .acc_in(acc_comb),
        .data_out(quantized_comb)
    );

    assign valid_out = valid_out_r;
    assign data_out  = data_out_r;

    always @(posedge clk) begin
        if (rst) begin
            delay_line_r <= {DATA_W*TAP_CNT{1'b0}};
            valid_out_r <= 1'b0;
            data_out_r  <= {OUT_W{1'b0}};
        end else begin
            valid_out_r <= valid_in;

            if (valid_in) begin
                delay_line_r <= delay_line_next;
                data_out_r   <= quantized_comb;
            end
        end
    end

endmodule