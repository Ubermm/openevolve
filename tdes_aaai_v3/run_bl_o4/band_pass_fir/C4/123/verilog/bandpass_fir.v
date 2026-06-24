`timescale 1ns/1ps
module bandpass_fir #(
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
    localparam PROD_W  = DATA_W + COEFF_W;
    // Latency = TAP_CNT-1 (shift register depth)
    // sample shift register
    reg signed [DATA_W-1:0] shift_reg [0:TAP_CNT-1];
    integer si;
    always @(posedge clk) begin
        if (rst) begin
            for (si = 0; si < TAP_CNT; si = si + 1)
                shift_reg[si] <= 0;
        end else if (valid_in) begin
            shift_reg[0] <= $signed(data_in);
            for (si = 1; si < TAP_CNT; si = si + 1)
                shift_reg[si] <= shift_reg[si-1];
        end
    end

    // valid pipeline
    reg valid_pipe [0:TAP_CNT-1];
    integer vi;
    always @(posedge clk) begin
        if (rst) begin
            for (vi = 0; vi < TAP_CNT; vi = vi + 1)
                valid_pipe[vi] <= 0;
        end else begin
            valid_pipe[0] <= valid_in;
            for (vi = 1; vi < TAP_CNT; vi = vi + 1)
                valid_pipe[vi] <= valid_pipe[vi-1];
        end
    end
    assign valid_out = valid_pipe[TAP_CNT-1];

    // instantiate coefficient ROMs
    wire [ $clog2(TAP_CNT)-1 : 0 ] addr_vec [0:TAP_CNT-1];
    wire signed [COEFF_W-1:0]      coef_vec [0:TAP_CNT-1];
    genvar gi;
    generate
        for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : GEN_ADDR
            assign addr_vec[gi] = gi;
            coeff_rom #(.TAP_CNT(TAP_CNT)) u_rom (
                .addr(addr_vec[gi]),
                .coef(coef_vec[gi])
            );
        end
    endgenerate

    // multiply taps by coefficients
    wire signed [PROD_W-1:0] prods [0:TAP_CNT-1];
    generate
        for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : GEN_MULT
            mult #(.A_W(DATA_W), .B_W(COEFF_W)) u_mult (
                .a(shift_reg[gi]),
                .b(coef_vec[gi]),
                .p(prods[gi])
            );
        end
    endgenerate

    // accumulate products
    reg signed [63:0] acc_sum;
    integer ai;
    always @* begin
        acc_sum = 0;
        for (ai = 0; ai < TAP_CNT; ai = ai + 1)
            acc_sum = acc_sum + prods[ai];
    end

    // shift right to scale (>> DATA_W)
    wire signed [DATA_W+GAIN_W-1:0] scaled;
    shift_arith #(
        .IN_W(64),
        .OUT_W(DATA_W+GAIN_W),
        .SHIFT(DATA_W)
    ) u_shift (
        .in(acc_sum),
        .out(scaled)
    );

    assign data_out = scaled;

endmodule