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
    output reg                  valid_out,
    output reg [DATA_W+GAIN_W-1:0] data_out
);

    localparam OUT_W   = DATA_W + GAIN_W;
    localparam COEFF_W = 16;
    localparam ACC_W   = 64;

    reg signed [DATA_W-1:0] sample_d [0:TAP_CNT-1];

    wire signed [DATA_W-1:0] data_in_s;
    wire [TAP_CNT*DATA_W-1:0] sample_state_flat;
    wire [TAP_CNT*DATA_W-1:0] next_samples_flat;
    wire [TAP_CNT*COEFF_W-1:0] coeff_flat;
    wire signed [ACC_W-1:0] acc_sum;
    wire signed [OUT_W-1:0] scaled_out;

    integer i;
    genvar g;

    assign data_in_s = data_in;

    generate
        for (g = 0; g < TAP_CNT; g = g + 1) begin : GEN_FLATTEN_SAMPLES
            assign sample_state_flat[g*DATA_W +: DATA_W] = sample_d[g];
        end
    endgenerate

    bpf_sample_shift #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) u_sample_shift (
        .sample_in(data_in_s),
        .samples_curr_flat(sample_state_flat),
        .samples_next_flat(next_samples_flat)
    );

    bpf_coeff_bank #(
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W)
    ) u_coeff_bank (
        .coeff_flat(coeff_flat)
    );

    bpf_mac #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_mac (
        .samples_flat(next_samples_flat),
        .coeff_flat(coeff_flat),
        .acc_out(acc_sum)
    );

    bpf_scale #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W),
        .SHIFT(15)
    ) u_scale (
        .acc_in(acc_sum),
        .data_out(scaled_out)
    );

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < TAP_CNT; i = i + 1) begin
                sample_d[i] <= {DATA_W{1'b0}};
            end
            valid_out <= 1'b0;
            data_out  <= {OUT_W{1'b0}};
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                for (i = 0; i < TAP_CNT; i = i + 1) begin
                    sample_d[i] <= next_samples_flat[i*DATA_W +: DATA_W];
                end
                data_out <= scaled_out;
            end
        end
    end

endmodule