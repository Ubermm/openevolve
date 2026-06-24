// Top-level iterative radix-2 FFT/IFFT for N=16, fixed-point
module fft16_iterative #(
  parameter N = 16,
  parameter DATA_W = 12,
  parameter COEFF_W = 16,
  parameter GAIN_W = 4
)(
  input                     clk,
  input                     rst,
  input                     start,
  input                     mode, // 0: FFT, 1: IFFT
  input signed [DATA_W-1:0] data_real_in  [0:N-1],
  input signed [DATA_W-1:0] data_imag_in  [0:N-1],
  output signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
  output signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
  output                    done
);
  localparam BITW = DATA_W + GAIN_W;
  // in-place buffer
  reg signed [BITW-1:0] buf_re [0:N-1];
  reg signed [BITW-1:0] buf_im [0:N-1];

  // control
  reg busy;
  reg done_r;
  reg [1:0] stage;
  reg [2:0] idx;
  assign done = done_r;

  // submodule wires
  wire [3:0] p, q;
  wire [3:0] tw_idx;
  wire signed [COEFF_W-1:0] tw_re, tw_im;
  wire signed [BITW-1:0] out_p_re, out_p_im, out_q_re, out_q_im;

  // address generation
  addr_gen addrgen (
    .stage(stage),
    .idx(idx),
    .p(p),
    .q(q),
    .tw_idx(tw_idx)
  );
  // twiddle ROM
  twiddle_rom #(.COEFF_W(COEFF_W)) rom (
    .idx(tw_idx),
    .mode(mode),
    .cos_q15(tw_re),
    .sin_q15(tw_im)
  );
  // butterfly
  butterfly #(.BITW(BITW), .C_W(COEFF_W)) bf (
    .p_re(buf_re[p]), .p_im(buf_im[p]),
    .q_re(buf_re[q]), .q_im(buf_im[q]),
    .tw_re(tw_re), .tw_im(tw_im),
    .out_p_re(out_p_re), .out_p_im(out_p_im),
    .out_q_re(out_q_re), .out_q_im(out_q_im)
  );

  integer i;
  // control FSM and datapath
  always @(posedge clk) begin
    if (rst) begin
      busy   <= 1'b0;
      done_r <= 1'b0;
      stage  <= 2'd0;
      idx    <= 3'd0;
      // clear buffer
      for (i = 0; i < N; i = i + 1) begin
        buf_re[i] <= {BITW{1'b0}};
        buf_im[i] <= {BITW{1'b0}};
      end
    end else begin
      if (start && !busy) begin
        // load inputs into buffer (sign-extend)
        busy   <= 1'b1;
        done_r <= 1'b0;
        stage  <= 2'd0;
        idx    <= 3'd0;
        for (i = 0; i < N; i = i + 1) begin
          buf_re[i] <= {{GAIN_W{data_real_in[i][DATA_W-1]}}, data_real_in[i]};
          buf_im[i] <= {{GAIN_W{data_imag_in[i][DATA_W-1]}}, data_imag_in[i]};
        end
      end else if (busy) begin
        // perform one butterfly at (stage, idx)
        buf_re[p] <= out_p_re;
        buf_im[p] <= out_p_im;
        buf_re[q] <= out_q_re;
        buf_im[q] <= out_q_im;
        // progress counters
        if (stage == 2'd3 && idx == 3'd7) begin
          busy   <= 1'b0;
          done_r <= 1'b1;
        end else begin
          if (idx == 3'd7) begin
            idx   <= 3'd0;
            stage <= stage + 1'b1;
          end else begin
            idx <= idx + 1'b1;
          end
        end
      end else begin
        // idle or after done
        done_r <= 1'b0;
      end
    end
  end

  // output with bit-reversal to natural order
  genvar gi;
  generate
    for (gi = 0; gi < N; gi = gi + 1) begin : OUTMAP
      // bit-reverse 4-bit index
      wire [3:0] rev = {gi[0], gi[1], gi[2], gi[3]};
      assign data_real_out[gi] = buf_re[rev];
      assign data_imag_out[gi] = buf_im[rev];
    end
  endgenerate

endmodule