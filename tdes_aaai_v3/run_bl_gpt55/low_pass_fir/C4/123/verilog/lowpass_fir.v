`timescale 1ns/1ps

module lowpass_fir #(
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

    localparam OUT_W       = DATA_W + GAIN_W;
    localparam COEFF_W     = 16;
    localparam ACC_W       = 64;
    localparam SCALE_SHIFT = 15;

    reg  [DATA_W-1:0] delay_reg [0:TAP_CNT-2];

    wire [TAP_CNT*DATA_W-1:0] sample_flat;
    wire [((TAP_CNT-1)/2)*(DATA_W+1)-1:0] pair_sum_flat;
    wire [DATA_W-1:0] center_sample;

    wire [((TAP_CNT-1)/2)*COEFF_W-1:0] coeff_pair_flat;
    wire [COEFF_W-1:0] coeff_center;

    wire signed [ACC_W-1:0] acc_comb;
    wire signed [OUT_W-1:0] scaled_comb;

    integer i;

    assign sample_flat[0 +: DATA_W] = data_in;

    genvar si;
    generate
        for (si = 1; si < TAP_CNT; si = si + 1) begin : gen_sample_flat
            assign sample_flat[si*DATA_W +: DATA_W] = delay_reg[si-1];
        end
    endgenerate

    fir_coeff_rom #(
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W)
    ) u_coeff_rom (
        .coeff_pair_flat(coeff_pair_flat),
        .coeff_center(coeff_center)
    );

    fir_symmetric_preadd #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) u_preadd (
        .sample_flat(sample_flat),
        .pair_sum_flat(pair_sum_flat),
        .center_sample(center_sample)
    );

    fir_parallel_mac #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_mac (
        .pair_sum_flat(pair_sum_flat),
        .center_sample(center_sample),
        .coeff_pair_flat(coeff_pair_flat),
        .coeff_center(coeff_center),
        .acc_out(acc_comb)
    );

    assign scaled_comb = acc_comb >>> SCALE_SHIFT;

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            data_out  <= {OUT_W{1'b0}};
            for (i = 0; i < TAP_CNT-1; i = i + 1) begin
                delay_reg[i] <= {DATA_W{1'b0}};
            end
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                data_out <= scaled_comb;

                delay_reg[0] <= data_in;
                for (i = 1; i < TAP_CNT-1; i = i + 1) begin
                    delay_reg[i] <= delay_reg[i-1];
                end
            end
        end
    end

endmodule