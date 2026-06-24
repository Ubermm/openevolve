`timescale 1ns/1ps

module highpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4
) (
    input                           clk,
    input                           rst,
    input                           valid_in,
    input      [DATA_W-1:0]         data_in,
    output reg                      valid_out,
    output reg [DATA_W+GAIN_W-1:0]  data_out
);

    localparam COEFF_W = 16;
    localparam PROD_W  = DATA_W + COEFF_W;
    localparam ACC_W   = 64;
    localparam OUT_W   = DATA_W + GAIN_W;

    reg signed [DATA_W-1:0] delay_line [0:TAP_CNT-1];

    wire signed [DATA_W-1:0] data_in_s;
    assign data_in_s = data_in;

    wire signed [COEFF_W-1:0] coeff      [0:TAP_CNT-1];
    wire signed [DATA_W-1:0]  tap_sample [0:TAP_CNT-1];
    wire signed [PROD_W-1:0]  product    [0:TAP_CNT-1];

    wire [PROD_W*TAP_CNT-1:0] product_flat;
    wire signed [ACC_W-1:0]   acc_sum;
    wire signed [OUT_W-1:0]   quantized_out;

    genvar gi;
    generate
        for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : GEN_TAPS
            wire [6:0] coeff_addr;
            assign coeff_addr = gi[6:0];

            hp_coeff_rom_comb #(
                .COEFF_W(COEFF_W)
            ) u_coeff_rom (
                .idx(coeff_addr),
                .coeff(coeff[gi])
            );

            if (gi == 0) begin : GEN_SAMPLE0
                assign tap_sample[gi] = data_in_s;
            end else begin : GEN_SAMPLEN
                assign tap_sample[gi] = delay_line[gi-1];
            end

            hp_sample_coeff_product #(
                .DATA_W(DATA_W),
                .COEFF_W(COEFF_W),
                .PROD_W(PROD_W)
            ) u_product (
                .sample(tap_sample[gi]),
                .coeff(coeff[gi]),
                .product(product[gi])
            );

            assign product_flat[gi*PROD_W +: PROD_W] = product[gi];
        end
    endgenerate

    hp_accumulate_products #(
        .TAP_CNT(TAP_CNT),
        .PROD_W(PROD_W),
        .ACC_W(ACC_W)
    ) u_accumulate (
        .products_flat(product_flat),
        .acc(acc_sum)
    );

    hp_quantize_shift #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W),
        .SHIFT(15)
    ) u_quantize (
        .acc(acc_sum),
        .data_out(quantized_out)
    );

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            data_out  <= {OUT_W{1'b0}};
            for (i = 0; i < TAP_CNT; i = i + 1) begin
                delay_line[i] <= {DATA_W{1'b0}};
            end
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                data_out <= quantized_out;

                delay_line[0] <= data_in_s;
                for (i = 1; i < TAP_CNT; i = i + 1) begin
                    delay_line[i] <= delay_line[i-1];
                end
            end
        end
    end

endmodule