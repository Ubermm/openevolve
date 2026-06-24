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
    // Internal wires
    wire signed [DATA_W-1:0] taps [0:TAP_CNT-1];
    wire signed [DATA_W+GAIN_W-1:0] acc_out;

    // Sub-module instantiations
    shift_regs #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) sr (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .data_in(data_in),
        .taps(taps)
    );

    valid_pipe #(
        .TAP_CNT(TAP_CNT)
    ) vp (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .valid_out(valid_out)
    );

    fir_acc #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT),
        .COEFF_W(16),
        .ACC_W(64),
        .GAIN_W(GAIN_W)
    ) acc (
        .taps(taps),
        .data_out(acc_out)
    );

    // Output assignment
    assign data_out = acc_out;

endmodule