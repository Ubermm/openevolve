// Top-level FIR filter module
// Implements a 101-tap symmetric low-pass FIR with streaming I/O.

module lowpass_fir #(
  parameter DATA_W  = 20,
  parameter TAP_CNT = 101,
  parameter GAIN_W  = 4,
  // derived
  parameter COEFF_W   = 16,
  parameter PAIR_W    = DATA_W+1,
  parameter PROD_W    = DATA_W+COEFF_W+1,
  parameter ACC_W     = DATA_W+COEFF_W+1 + $clog2(TAP_CNT)
) (
  input                       clk,
  input                       rst,
  input                       valid_in,
  input      [DATA_W-1:0]     data_in,
  output reg                  valid_out,
  output reg signed [DATA_W+GAIN_W-1:0] data_out
);

  // Signed version of incoming data
  wire signed [DATA_W-1:0] din_s = $signed(data_in);

  // Shift register for samples
  reg signed [DATA_W-1:0] taps [0:TAP_CNT-1];
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < TAP_CNT; i = i+1)
        taps[i] <= 0;
    end else begin
      taps[0] <= din_s;
      for (i = 1; i < TAP_CNT; i = i+1)
        taps[i] <= taps[i-1];
    end
  end

  // Valid pipeline length = TAP_CNT cycles
  reg [TAP_CNT-1:0] vpipe;
  always @(posedge clk) begin
    if (rst) begin
      vpipe <= {TAP_CNT{1'b0}};
      valid_out <= 1'b0;
    end else begin
      vpipe[0] <= valid_in;
      vpipe[1 +: TAP_CNT-1] <= vpipe[0 +: TAP_CNT-1];
      valid_out <= vpipe[TAP_CNT-1];
    end
  end

  // Compute products for symmetric pairs
  wire signed [PROD_W-1:0] prods [0:(TAP_CNT+1)/2-1];
  genvar idx;
  generate
    // instantiate coefficient ROMs and pair_mac for indices 0..(TAP_CNT-1)/2
    for (idx = 0; idx < (TAP_CNT+1)/2; idx = idx+1) begin : GEN_MAC
      // get coefficient
      wire signed [COEFF_W-1:0] c;
      coeff_rom #(.TAP_CNT(TAP_CNT), .COEFF_W(COEFF_W)) rom (
        .addr(idx),
        .coeff(c)
      );
      // two sample indices
      wire signed [DATA_W-1:0] a = taps[idx];
      wire signed [DATA_W-1:0] b = taps[TAP_CNT-1-idx];
      pair_mac #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) mac (
        .dataA(a),
        .dataB(b),
        .coeff(c),
        .product(prods[idx])
      );
    end
  endgenerate

  // Accumulate all products
  wire signed [ACC_W-1:0] acc_sum;
  // flatten sum via generate-add
  assign acc_sum = prods[0]
                 + prods[1]
                 + prods[2]
                 + prods[3]
                 + prods[4]
                 + prods[5]
                 + prods[6]
                 + prods[7]
                 + prods[8]
                 + prods[9]
                 + prods[10]
                 + prods[11]
                 + prods[12]
                 + prods[13]
                 + prods[14]
                 + prods[15]
                 + prods[16]
                 + prods[17]
                 + prods[18]
                 + prods[19]
                 + prods[20]
                 + prods[21]
                 + prods[22]
                 + prods[23]
                 + prods[24]
                 + prods[25]
                 + prods[26]
                 + prods[27]
                 + prods[28]
                 + prods[29]
                 + prods[30]
                 + prods[31]
                 + prods[32]
                 + prods[33]
                 + prods[34]
                 + prods[35]
                 + prods[36]
                 + prods[37]
                 + prods[38]
                 + prods[39]
                 + prods[40]
                 + prods[41]
                 + prods[42]
                 + prods[43]
                 + prods[44]
                 + prods[45]
                 + prods[46]
                 + prods[47]
                 + prods[48]
                 + prods[49]
                 + prods[50];

  // Scale and truncate output
  wire signed [DATA_W+GAIN_W-1:0] comb_out;
  out_shift #(.DATA_W(DATA_W), .GAIN_W(GAIN_W), .ACC_W(ACC_W)) scaler (
    .acc(acc_sum),
    .out(comb_out)
  );

  // Register output data
  always @(posedge clk) begin
    if (rst)
      data_out <= 0;
    else
      data_out <= comb_out;
  end

endmodule