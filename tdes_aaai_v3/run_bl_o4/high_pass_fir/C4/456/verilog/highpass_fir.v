// Top-level high-pass FIR filter with streaming interface
// Parameterizable DATA_W, TAP_CNT, GAIN_W
module highpass_fir #(
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

    // Local widths
    localparam COEFF_W = 16;
    localparam SUM_W   = 64;
    // Pipeline registers
    reg                   valid_pipe [0:TAP_CNT-1];
    reg signed [DATA_W-1:0] sample_pipe [0:TAP_CNT-1];
    reg signed [SUM_W-1:0]  sum_pipe    [0:TAP_CNT-1];

    // Wires for coefficients and MAC outputs
    wire signed [COEFF_W-1:0] coeffs   [0:TAP_CNT-1];
    wire signed [SUM_W-1:0]   mac_out  [0:TAP_CNT-1];

    // Coefficient ROM instances
    genvar ci;
    generate
        for (ci = 0; ci < TAP_CNT; ci = ci + 1) begin : COEFF_GEN
            fir_coeff #(.ADDR(ci)) u_coeff (.coeff_out(coeffs[ci]));
        end
    endgenerate

    // MAC pipeline: 101 stages
    genvar mi;
    generate
        for (mi = 0; mi < TAP_CNT; mi = mi + 1) begin : MAC_GEN
            if (mi == 0) begin
                // First stage: sum_in = 0
                fir_mac #(.DATA_W(DATA_W)) u_mac0 (
                    .sum_in (64'sd0),
                    .data_in(sample_pipe[0]),
                    .coeff_in(coeffs[0]),
                    .sum_out(mac_out[0])
                );
            end else begin
                // Subsequent stages
                fir_mac #(.DATA_W(DATA_W)) u_macN (
                    .sum_in (sum_pipe[mi-1]),
                    .data_in(sample_pipe[mi]),
                    .coeff_in(coeffs[mi]),
                    .sum_out(mac_out[mi])
                );
            end
        end
    endgenerate

    // Output stage: shift and truncate
    fir_output #(.DATA_W(DATA_W), .GAIN_W(GAIN_W)) u_output (
        .sum_in  (sum_pipe[TAP_CNT-1]),
        .data_out(data_out)
    );

    // valid_out from last stage
    assign valid_out = valid_pipe[TAP_CNT-1];

    // Pipeline registers update
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            // reset all pipeline
            for (i = 0; i < TAP_CNT; i = i + 1) begin
                valid_pipe[i]      <= 1'b0;
                sample_pipe[i]     <= {DATA_W{1'b0}};
                sum_pipe[i]        <= {SUM_W{1'b0}};
            end
        end else begin
            // stage 0
            valid_pipe[0]  <= valid_in;
            sample_pipe[0] <= (valid_in ? $signed(data_in) : {DATA_W{1'b0}});
            sum_pipe[0]    <= mac_out[0];
            // stages 1..TAP_CNT-1
            for (i = 1; i < TAP_CNT; i = i + 1) begin
                valid_pipe[i]  <= valid_pipe[i-1];
                sample_pipe[i] <= sample_pipe[i-1];
                sum_pipe[i]    <= mac_out[i];
            end
        end
    end

endmodule