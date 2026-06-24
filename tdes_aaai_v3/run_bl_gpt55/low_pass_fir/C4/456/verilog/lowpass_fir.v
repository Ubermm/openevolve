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

    localparam OUT_W    = DATA_W + GAIN_W;
    localparam COEFF_W  = 16;
    localparam ACC_W    = 64;
    localparam DELAY_CT = TAP_CNT - 1;
    localparam PAIR_CNT = (TAP_CNT - 1) / 2;
    localparam PAIR_W   = DATA_W + 1;

    reg [DATA_W-1:0] delay_line [0:DELAY_CT-1];

    wire [DELAY_CT*DATA_W-1:0] delay_flat;
    wire [TAP_CNT*DATA_W-1:0]  sample_flat;
    wire [TAP_CNT*COEFF_W-1:0] coeff_flat;
    wire [PAIR_CNT*PAIR_W-1:0] pair_sums_flat;
    wire [DATA_W-1:0]          center_sample;
    wire signed [ACC_W-1:0]    fir_acc;
    wire [OUT_W-1:0]           scaled_out;

    genvar gi;
    generate
        for (gi = 0; gi < DELAY_CT; gi = gi + 1) begin : GEN_DELAY_FLAT
            assign delay_flat[gi*DATA_W +: DATA_W] = delay_line[gi];
        end
    endgenerate

    fir_coeff_rom_101 #(
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W)
    ) u_coeff_rom (
        .coeff_flat(coeff_flat)
    );

    fir_sample_formatter #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) u_sample_formatter (
        .data_in(data_in),
        .delay_flat(delay_flat),
        .sample_flat(sample_flat)
    );

    fir_symmetric_preadder #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) u_preadder (
        .sample_flat(sample_flat),
        .pair_sums_flat(pair_sums_flat),
        .center_sample(center_sample)
    );

    fir_symmetric_mac #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_mac (
        .pair_sums_flat(pair_sums_flat),
        .center_sample(center_sample),
        .coeff_flat(coeff_flat),
        .acc_out(fir_acc)
    );

    fir_output_scaler #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W),
        .SHIFT_BITS(20)
    ) u_scaler (
        .acc_in(fir_acc),
        .data_out(scaled_out)
    );

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            data_out  <= {OUT_W{1'b0}};
            for (i = 0; i < DELAY_CT; i = i + 1) begin
                delay_line[i] <= {DATA_W{1'b0}};
            end
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                data_out <= scaled_out;

                delay_line[0] <= data_in;
                for (i = 1; i < DELAY_CT; i = i + 1) begin
                    delay_line[i] <= delay_line[i-1];
                end
            end
        end
    end

endmodule