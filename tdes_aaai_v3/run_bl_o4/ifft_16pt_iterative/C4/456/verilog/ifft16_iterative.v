// Top-level iterative 16-point fixed-point IFFT/FFT (mode-controlled) module
module ifft16_iterative #(
  parameter N = 16,
  parameter DATA_W = 12,
  parameter COEFF_W = 16,
  parameter GAIN_W = 4
) (
  input                       clk,
  input                       rst,
  input                       start,
  input                       mode, // 0: FFT, 1: IFFT (we always use IFFT conjugate table when mode=1)
  input  signed [DATA_W-1:0]  data_real_in  [0:N-1],
  input  signed [DATA_W-1:0]  data_imag_in  [0:N-1],
  output reg signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
  output reg signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
  output reg                  done
);

  // FSM states
  localparam IDLE   = 2'd0;
  localparam STAGE  = 2'd1;
  localparam BITREV = 2'd2;

  // Internal regs
  reg [1:0]          state;
  reg [1:0]          stageCnt;     // 0..3 for 4 stages
  reg [3:0]          bc;           // butterfly counter (0..7)
  reg [3:0]          brCnt;        // bit-reverse output counter (0..15)

  // Data memory (in-place)
  reg signed [DATA_W+GAIN_W-1:0] mem_re [0:N-1];
  reg signed [DATA_W+GAIN_W-1:0] mem_im [0:N-1];

  // Wires for butterfly
  wire [DATA_W+GAIN_W-1:0]      x0_re = mem_re[p];
  wire [DATA_W+GAIN_W-1:0]      x0_im = mem_im[p];
  wire [DATA_W+GAIN_W-1:0]      x1_re = mem_re[q];
  wire [DATA_W+GAIN_W-1:0]      x1_im = mem_im[q];

  wire [DATA_W+GAIN_W-1:0]      y0_re, y0_im, y1_re, y1_im;
  wire signed [COEFF_W-1:0]     cos_w, sin_w;
  wire [3:0]                    twidx;
  wire [3:0]                    half;
  wire [4:0]                    m;
  wire [3:0]                    step;
  wire [3:0]                    rev_idx;
  wire [3:0]                    p;
  wire [4:0]                    q;

  integer i;

  // Compute half, m, step for current stage
  assign half = (1 << stageCnt);
  assign m    = (half << 1);
  assign step = (N >> (stageCnt + 1));

  // Compute butterfly indices and twiddle index
  // jIndex = bc & (half-1); kIndex = bc >> stageCnt
  assign p     = ((bc >> stageCnt) * m) + (bc & (half - 1));
  assign q     = p + half;
  assign twidx = (bc & (half - 1)) * step;

  // Instantiate twiddle ROM
  twiddle_rom #(
    .COEFF_W(COEFF_W)
  ) rom_fft (
    .addr (twidx),
    .mode (mode),
    .cos_w(cos_w),
    .sin_w(sin_w)
  );

  // Instantiate combinational butterfly
  butterfly_comb #(
    .DATA_W(DATA_W+GAIN_W),
    .COEFF_W(COEFF_W)
  ) bf (
    .x0_re (x0_re),
    .x0_im (x0_im),
    .x1_re (x1_re),
    .x1_im (x1_im),
    .cos_w (cos_w),
    .sin_w (sin_w),
    .y0_re (y0_re),
    .y0_im (y0_im),
    .y1_re (y1_re),
    .y1_im (y1_im)
  );

  // Instantiate bit-reverse for output indexing
  bit_reverse4 br4 (
    .addr(brCnt[3:0]),
    .rev (rev_idx)
  );

  // Top-level FSM and datapath
  always @(posedge clk) begin
    if (rst) begin
      state    <= IDLE;
      done     <= 1'b0;
      bc       <= 4'd0;
      stageCnt <= 2'd0;
      brCnt    <= 4'd0;
      // clear outputs (optional)
      for (i = 0; i < N; i = i + 1) begin
        data_real_out[i] <= { (GAIN_W+DATA_W){1'b0} };
        data_imag_out[i] <= { (GAIN_W+DATA_W){1'b0} };
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Load inputs (sign-extend 12->16 bits)
            for (i = 0; i < N; i = i + 1) begin
              mem_re[i] <= {{GAIN_W{data_real_in[i][DATA_W-1]}}, data_real_in[i]};
              mem_im[i] <= {{GAIN_W{data_imag_in[i][DATA_W-1]}}, data_imag_in[i]};
            end
            stageCnt <= 2'd0;
            bc       <= 4'd0;
            state    <= STAGE;
          end
        end

        STAGE: begin
          // Write butterfly outputs back to memory
          mem_re[p] <= y0_re;
          mem_im[p] <= y0_im;
          mem_re[q] <= y1_re;
          mem_im[q] <= y1_im;

          // Advance butterfly counter or stage
          if (bc == (N/2 - 1)) begin
            bc <= 4'd0;
            if (stageCnt == 2'd3) begin
              // All 4 stages done, move to bit-reversal + scaling
              brCnt <= 4'd0;
              state <= BITREV;
            end else begin
              stageCnt <= stageCnt + 2'd1;
            end
          end else begin
            bc <= bc + 4'd1;
          end
        end

        BITREV: begin
          // Output with bit-reversal and final scaling (/16 via >>>4)
          data_real_out[rev_idx] <= mem_re[brCnt] >>> GAIN_W;
          data_imag_out[rev_idx] <= mem_im[brCnt] >>> GAIN_W;

          if (brCnt == (N - 1)) begin
            done  <= 1'b1;
            state <= IDLE;
          end else begin
            brCnt <= brCnt + 4'd1;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule