`timescale 1ns/1ps
module bandpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4,
    parameter COEFF_W = 16,
    parameter SUM_W   = 64
) (
    input                       clk,
    input                       rst,
    input                       valid_in,
    input      [DATA_W-1:0]     data_in,
    output                      valid_out,
    output     [DATA_W+GAIN_W-1:0] data_out
);
    // Pipeline registers for samples and partial sums
    // sample_pipe[0] is current input, sample_pipe[TAP_CNT] is last-stage sample
    reg signed [DATA_W-1:0]   sample_pipe [0:TAP_CNT];
    reg signed [SUM_W-1:0]    sum_pipe    [0:TAP_CNT];
    // Valid pipeline: depth = TAP_CNT
    reg [TAP_CNT:0]           valid_pipe;

    // Wires for combinational MAC outputs and coefficients
    wire signed [DATA_W-1:0]  sample_c [0:TAP_CNT-1];
    wire signed [SUM_W-1:0]   sum_c    [0:TAP_CNT-1];
    wire signed [COEFF_W-1:0] coeff   [0:TAP_CNT-1];

    // Instantiate coefficient ROM and MAC stages
    genvar i;
    generate
        for (i = 0; i < TAP_CNT; i = i + 1) begin : stages
            // Coefficient ROM
            coeff_rom #(.ADDR_W(7), .COEFF_W(COEFF_W)) u_rom (
                .index(i[6:0]),
                .coeff(coeff[i])
            );
            // Combinational MAC
            fir_mac #(
                .DATA_W(DATA_W),
                .COEFF_W(COEFF_W),
                .SUM_W(SUM_W)
            ) u_mac (
                .sum_in(sum_pipe[i]),
                .sample_in(sample_pipe[i]),
                .coeff(coeff[i]),
                .sum_out(sum_c[i]),
                .sample_out(sample_c[i])
            );
        end
    endgenerate

    // Scaler: right shift by DATA_W
    scaler #(
        .DATA_W(DATA_W),
        .GAIN_W(GAIN_W),
        .SUM_W(SUM_W)
    ) u_scaler (
        .sum_in(sum_pipe[TAP_CNT]),
        .data_out(data_out)
    );

    // Valid output
    assign valid_out = valid_pipe[TAP_CNT];

    integer j;
    always @(posedge clk) begin
        if (rst) begin
            // reset pipelines
            for (j = 0; j <= TAP_CNT; j = j + 1) begin
                sample_pipe[j] <= 0;
                sum_pipe[j]    <= 0;
            end
            valid_pipe <= 0;
        end else begin
            // input stage
            sample_pipe[0] <= data_in;
            sum_pipe[0]    <= 0;
            // shift through stages
            for (j = 0; j < TAP_CNT; j = j + 1) begin
                sample_pipe[j+1] <= sample_c[j];
                sum_pipe[j+1]    <= sum_c[j];
            end
            // valid shift
            valid_pipe[0] <= valid_in;
            valid_pipe[TAP_CNT:1] <= valid_pipe[TAP_CNT-1:0];
        end
    end

endmodule