`timescale 1ns/1ps

module lowpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4
) (
    input                          clk,
    input                          rst,
    input                          valid_in,
    input      [DATA_W-1:0]        data_in,
    output                         valid_out,
    output     [DATA_W+GAIN_W-1:0] data_out
);

    localparam OUT_W       = DATA_W + GAIN_W;
    localparam COEFF_W     = 16;
    localparam HALF        = (TAP_CNT - 1) / 2;   // 50 for 101 taps
    localparam PAIR_CNT    = HALF + 1;            // 50 symmetric pairs + center
    localparam PREADD_W    = DATA_W + 1;
    localparam PRODUCT_W   = PREADD_W + COEFF_W;
    localparam ACC_W       = 64;
    localparam SHIFT_BITS  = 20;

    reg signed [DATA_W-1:0] delay_line [0:TAP_CNT-2];

    wire signed [DATA_W-1:0] data_in_s;
    assign data_in_s = data_in;

    wire signed [PAIR_CNT*PRODUCT_W-1:0] product_bus;
    wire signed [ACC_W-1:0]              acc_comb;
    wire signed [OUT_W-1:0]              quantized_comb;

    reg valid_out_r;
    reg [OUT_W-1:0] data_out_r;

    assign valid_out = valid_out_r;
    assign data_out  = data_out_r;

    genvar gi;
    generate
        for (gi = 0; gi < HALF; gi = gi + 1) begin : GEN_SYM_PAIR
            localparam [6:0] CIDX = gi;

            wire signed [DATA_W-1:0]     sample_lo;
            wire signed [DATA_W-1:0]     sample_hi;
            wire signed [PREADD_W-1:0]   preadd_sum;
            wire signed [COEFF_W-1:0]    coeff_val;
            wire signed [PRODUCT_W-1:0]  product_val;

            if (gi == 0) begin : GEN_LO_CURRENT
                assign sample_lo = data_in_s;
            end else begin : GEN_LO_DELAY
                assign sample_lo = delay_line[gi-1];
            end

            assign sample_hi = delay_line[TAP_CNT-2-gi];

            lowpass_fir_symmetric_preadd #(
                .DATA_W(DATA_W)
            ) u_preadd (
                .sample_a(sample_lo),
                .sample_b(sample_hi),
                .sum_out(preadd_sum)
            );

            lowpass_fir_coeff_rom #(
                .COEFF_W(COEFF_W)
            ) u_coeff (
                .addr(CIDX),
                .coeff(coeff_val)
            );

            lowpass_fir_product #(
                .SAMPLE_W(PREADD_W),
                .COEFF_W(COEFF_W),
                .PRODUCT_W(PRODUCT_W)
            ) u_product (
                .sample_sum(preadd_sum),
                .coeff(coeff_val),
                .product(product_val)
            );

            assign product_bus[gi*PRODUCT_W +: PRODUCT_W] = product_val;
        end
    endgenerate

    wire signed [PREADD_W-1:0]  center_sample_ext;
    wire signed [COEFF_W-1:0]   center_coeff;
    wire signed [PRODUCT_W-1:0] center_product;

    assign center_sample_ext = {delay_line[HALF-1][DATA_W-1], delay_line[HALF-1]};

    lowpass_fir_coeff_rom #(
        .COEFF_W(COEFF_W)
    ) u_center_coeff (
        .addr(7'd50),
        .coeff(center_coeff)
    );

    lowpass_fir_product #(
        .SAMPLE_W(PREADD_W),
        .COEFF_W(COEFF_W),
        .PRODUCT_W(PRODUCT_W)
    ) u_center_product (
        .sample_sum(center_sample_ext),
        .coeff(center_coeff),
        .product(center_product)
    );

    assign product_bus[HALF*PRODUCT_W +: PRODUCT_W] = center_product;

    lowpass_fir_adder_tree #(
        .TERM_CNT(PAIR_CNT),
        .TERM_W(PRODUCT_W),
        .ACC_W(ACC_W)
    ) u_adder_tree (
        .terms(product_bus),
        .acc(acc_comb)
    );

    lowpass_fir_output_quantize #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W),
        .SHIFT_BITS(SHIFT_BITS)
    ) u_quantize (
        .acc(acc_comb),
        .data_out(quantized_comb)
    );

    integer si;
    always @(posedge clk) begin
        if (rst) begin
            for (si = 0; si < TAP_CNT-1; si = si + 1) begin
                delay_line[si] <= {DATA_W{1'b0}};
            end
            valid_out_r <= 1'b0;
            data_out_r  <= {OUT_W{1'b0}};
        end else begin
            valid_out_r <= valid_in;

            if (valid_in) begin
                data_out_r <= quantized_comb;

                delay_line[0] <= data_in_s;
                for (si = 1; si < TAP_CNT-1; si = si + 1) begin
                    delay_line[si] <= delay_line[si-1];
                end
            end
        end
    end

endmodule