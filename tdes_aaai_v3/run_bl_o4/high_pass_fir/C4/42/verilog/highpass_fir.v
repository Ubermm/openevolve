// Top-level high-pass FIR filter (streaming, 1 sample/cycle)
// Latency = TAP_CNT-1 cycles (zero-extended)
module highpass_fir #(
    parameter DATA_W   = 20,
    parameter TAP_CNT  = 101,
    parameter GAIN_W   = 4,
    parameter COEFF_W  = 16
)(
    input                       clk,
    input                       rst,        // synchronous, active-high
    input                       valid_in,
    input       signed [DATA_W-1:0] data_in,
    output reg                  valid_out,
    output reg  signed [DATA_W+GAIN_W-1:0] data_out
);

    //========================================================================
    // 1) Coefficient ROM (combinational)
    //========================================================================
    wire signed [COEFF_W-1:0] coeffs [0:TAP_CNT-1];
    hpf_coeff_mem #(
        .TAP_CNT(TAP_CNT),
        .COEFF_W(COEFF_W)
    ) coeff_inst (
        .coeffs(coeffs)
    );

    //========================================================================
    // 2) Shift-register of recent samples (zero-extension after valid_in=0)
    //========================================================================
    reg signed [DATA_W-1:0] taps [0:TAP_CNT-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < TAP_CNT; i = i + 1)
                taps[i] <= 0;
        end else begin
            // new sample or zero
            taps[0] <= valid_in ? data_in : {DATA_W{1'b0}};
            // shift
            for (i = 1; i < TAP_CNT; i = i + 1)
                taps[i] <= taps[i-1];
        end
    end

    //========================================================================
    // 3) Valid pipeline (delay valid_in by TAP_CNT-1 cycles)
    //========================================================================
    reg [TAP_CNT-1:0] valid_pipe;
    always @(posedge clk) begin
        if (rst) valid_pipe <= {TAP_CNT{1'b0}};
        else     valid_pipe <= { valid_pipe[TAP_CNT-2:0], valid_in };
    end
    wire ready = valid_pipe[TAP_CNT-1];

    //========================================================================
    // 4) Dot-product MAC (combinational)
    //========================================================================
    wire signed [63:0] mac_sum;
    hpf_dot_product #(
        .TAP_CNT(TAP_CNT),
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W)
    ) mac_inst (
        .taps(taps),
        .coeffs(coeffs),
        .sum_out(mac_sum)
    );

    //========================================================================
    // 5) Scaler / output generator (combinational)
    //========================================================================
    wire signed [DATA_W+GAIN_W-1:0] scaled;
    hpf_scaler #(
        .DATA_W(DATA_W),
        .GAIN_W(GAIN_W)
    ) scale_inst (
        .sum_in(mac_sum),
        .data_out(scaled)
    );

    //========================================================================
    // 6) Output registers
    //========================================================================
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            data_out  <= {DATA_W+GAIN_W{1'b0}};
        end else begin
            valid_out <= ready;
            data_out  <= scaled;
        end
    end

endmodule