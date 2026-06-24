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
    output                      valid_out,
    output     [DATA_W+GAIN_W-1:0] data_out
);
    // Internal parameters
    localparam COEFF_W = 16;
    localparam SHIFT   = 15; // scale = 2^15 =32768
    localparam PROD_W  = DATA_W + COEFF_W;
    localparam ACC_W   = PROD_W + $clog2(TAP_CNT);
    localparam OUT_W   = DATA_W + GAIN_W;

    // Shift register for samples
    reg signed [DATA_W-1:0] taps [0:TAP_CNT-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i=0; i<TAP_CNT; i=i+1)
                taps[i] <= {DATA_W{1'b0}};
        end else begin
            // shift
            for (i=TAP_CNT-1; i>0; i=i-1)
                taps[i] <= taps[i-1];
            // new sample or zero
            taps[0] <= valid_in ? data_in : {DATA_W{1'b0}};
        end
    end

    // flatten taps
    wire signed [DATA_W*TAP_CNT-1:0] taps_flat;
    generate
        genvar gi;
        for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : FLT
            assign taps_flat[gi*DATA_W +: DATA_W] = taps[gi];
        end
    endgenerate

    // coefficient store
    wire signed [COEFF_W*TAP_CNT-1:0] coeffs_flat;
    coeff_store #(.COEFF_W(COEFF_W), .TAP_CNT(TAP_CNT)) u_coeff (
        .coeffs(coeffs_flat)
    );

    // multiply array
    wire signed [PROD_W*TAP_CNT-1:0] prods_flat;
    mult_array #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .TAP_CNT(TAP_CNT)
    ) u_mult (
        .taps(taps_flat),
        .coeffs(coeffs_flat),
        .prods(prods_flat)
    );

    // adder tree and shift
    adder_tree #(
        .TAP_CNT(TAP_CNT),
        .PROD_W(PROD_W),
        .ACC_W(ACC_W),
        .SHIFT(SHIFT),
        .OUT_W(OUT_W)
    ) u_add (
        .prods(prods_flat),
        .data_out(data_out)
    );

    // output valid
    assign valid_out = valid_in & ~rst;

endmodule