`timescale 1ns/1ps

module bandpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4
) (
    input                         clk,
    input                         rst,
    input                         valid_in,
    input      [DATA_W-1:0]       data_in,
    output reg                    valid_out,
    output reg [DATA_W+GAIN_W-1:0] data_out
);

    localparam COEFF_W = 16;
    localparam ACC_W   = 64;
    localparam OUT_W   = DATA_W + GAIN_W;

    reg signed [DATA_W-1:0] delay_line [0:TAP_CNT-2];

    wire [TAP_CNT*DATA_W-1:0]  samples_flat;
    wire [TAP_CNT*COEFF_W-1:0] coeffs_flat;
    wire signed [ACC_W-1:0]    acc_full;
    wire signed [OUT_W-1:0]    quantized_out;

    integer i;
    genvar g;

    assign samples_flat[0 +: DATA_W] = data_in;

    generate
        for (g = 1; g < TAP_CNT; g = g + 1) begin : GEN_SAMPLE_FLAT
            assign samples_flat[g*DATA_W +: DATA_W] = delay_line[g-1];
        end
    endgenerate

    bandpass_fir_coeffs #(
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W)
    ) u_coeffs (
        .coeffs_flat(coeffs_flat)
    );

    bandpass_fir_mac #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_mac (
        .samples_flat(samples_flat),
        .coeffs_flat(coeffs_flat),
        .acc_out(acc_full)
    );

    bandpass_fir_quantize #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W),
        .SHIFT_BITS(15)
    ) u_quantize (
        .acc_in(acc_full),
        .data_out(quantized_out)
    );

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            data_out  <= {OUT_W{1'b0}};
            for (i = 0; i < TAP_CNT-1; i = i + 1) begin
                delay_line[i] <= {DATA_W{1'b0}};
            end
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                data_out <= quantized_out;

                delay_line[0] <= data_in;
                for (i = 1; i < TAP_CNT-1; i = i + 1) begin
                    delay_line[i] <= delay_line[i-1];
                end
            end
        end
    end

endmodule