// Top-level high-pass FIR filter: fully pipelined systolic MAC array
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
    // Local parameters
    localparam COEFF_W = 16;
    localparam ACC_W   = 64;
    localparam SHIFT   = DATA_W;

    // Delay register for valid signal
    reg r_valid [0:TAP_CNT];
    integer vi;
    // Pipeline registers for data and accumulator sums
    reg signed [DATA_W-1:0] data_pipe [0:TAP_CNT];
    reg signed [ACC_W-1:0] sum_pipe  [0:TAP_CNT];
    integer di;

    // Output of final sum after last MAC stage
    wire signed [ACC_W-1:0] final_sum = sum_pipe[TAP_CNT];
    // Scaled output
    wire signed [DATA_W+GAIN_W-1:0] scaled;
    assign data_out = scaled;
    assign valid_out = r_valid[TAP_CNT];

    // Instantiate final scaler (comb) to right-shift accumulator by DATA_W bits
    scaler #(
        .ACC_W(ACC_W),
        .DATA_OUT_W(DATA_W+GAIN_W),
        .SHIFT(SHIFT)
    ) u_scaler (
        .acc(final_sum),
        .out(scaled)
    );

    // Shift-register for valid_in → valid_out
    always @(posedge clk) begin
        if (rst) begin
            for (vi = 0; vi <= TAP_CNT; vi = vi + 1)
                r_valid[vi] <= 1'b0;
        end else begin
            r_valid[0] <= valid_in;
            for (vi = 1; vi <= TAP_CNT; vi = vi + 1)
                r_valid[vi] <= r_valid[vi-1];
        end
    end

    // Initialize stage-0 data and sum
    always @(posedge clk) begin
        if (rst) begin
            data_pipe[0] <= {DATA_W{1'b0}};
            sum_pipe[0]  <= {ACC_W{1'b0}};
        end else begin
            data_pipe[0] <= $signed(data_in);
            sum_pipe[0]  <= {ACC_W{1'b0}};
        end
    end

    // Generate TAP_CNT multiply-accumulate stages
    genvar j;
    generate
      for (j = 0; j < TAP_CNT; j = j + 1) begin : stages
        // Stage inputs
        wire signed [DATA_W-1:0] data_in_j = data_pipe[j];
        wire signed [ACC_W-1:0]  sum_in_j  = sum_pipe[j];
        // Stage outputs (combinational)
        wire signed [DATA_W-1:0] data_out_j;
        wire signed [ACC_W-1:0]  sum_out_j;
        // Coefficient for this tap
        wire [6:0]               idx_j = j;
        wire signed [COEFF_W-1:0] coeff_j;

        // Coefficient ROM instance
        coeff_rom #(
          .TAP_CNT(TAP_CNT),
          .COEFF_W(COEFF_W)
        ) u_cr (
          .idx(idx_j),
          .coeff(coeff_j)
        );

        // Multiply-add stage instance
        mult_add_stage #(
          .DATA_W(DATA_W),
          .COEFF_W(COEFF_W),
          .ACC_W(ACC_W)
        ) u_mas (
          .data_in(data_in_j),
          .sum_in(sum_in_j),
          .coeff(coeff_j),
          .data_out(data_out_j),
          .sum_out(sum_out_j)
        );

        // Pipeline registers for next stage
        always @(posedge clk) begin
          if (rst) begin
            data_pipe[j+1] <= {DATA_W{1'b0}};
            sum_pipe[j+1]  <= {ACC_W{1'b0}};
          end else begin
            data_pipe[j+1] <= data_out_j;
            sum_pipe[j+1]  <= sum_out_j;
          end
        end
      end
    endgenerate

endmodule