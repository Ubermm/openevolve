`timescale 1ns/1ps
module ifft16_iterative #(
  parameter N       = 16,
  parameter DATA_W  = 12,
  parameter COEFF_W = 16,
  parameter GAIN_W  = 4
) (
  input                         clk,
  input                         rst,
  input                         start,
  input                         mode, // unused, always IFFT
  input  signed [DATA_W-1:0]    data_real_in  [0:N-1],
  input  signed [DATA_W-1:0]    data_imag_in  [0:N-1],
  output signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
  output signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
  output                        done
);

  // internal memory for iterative computation
  reg signed [DATA_W+GAIN_W-1:0] mem_real [0:N-1];
  reg signed [DATA_W+GAIN_W-1:0] mem_imag [0:N-1];

  // FSM and counters
  localparam IDLE = 2'd0, CALC = 2'd1, DONE_ST = 2'd2;
  reg [1:0] state;
  reg [5:0] iter_cnt;
  reg       done_reg;
  assign done = done_reg;

  // compute butterfly indices and twiddle index
  wire [2:0] stage     = iter_cnt[5:3];          // 0..3
  wire [3:0] half_m    = 1 << stage;             // 1,2,4,8
  wire [4:0] span      = half_m << 1;            // 2,4,8,16
  wire [3:0] grp_cnt   = N >> (stage+1);         // 8,4,2,1
  wire [3:0] j         = iter_cnt >> (3-stage);  // iter / grp_cnt
  wire [3:0] group     = iter_cnt & (grp_cnt-1); // iter % grp_cnt
  wire [3:0] p_idx     = (group << (stage+1)) + j;
  wire [3:0] q_idx     = p_idx + half_m;
  wire [3:0] tw_idx    = j * grp_cnt;

  // twiddle values
  wire signed [COEFF_W-1:0] cos_q15, sin_q15;
  twiddle_rom #(.COEFF_W(COEFF_W)) u_rom (
    .addr(tw_idx), .cos_q15(cos_q15), .sin_q15(sin_q15)
  );

  // butterfly outputs
  wire signed [DATA_W+GAIN_W-1:0] bf_p_re, bf_p_im, bf_q_re, bf_q_im;
  butterfly_unit #(.DATA_W(DATA_W), .GAIN_W(GAIN_W), .COEFF_W(COEFF_W))
    u_bf (
      .p_re_in(mem_real[p_idx]),
      .p_im_in(mem_imag[p_idx]),
      .q_re_in(mem_real[q_idx]),
      .q_im_in(mem_imag[q_idx]),
      .cos_q15(cos_q15),
      .sin_q15(sin_q15),
      .p_re_out(bf_p_re),
      .p_im_out(bf_p_im),
      .q_re_out(bf_q_re),
      .q_im_out(bf_q_im)
    );

  // FSM
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      state    <= IDLE;
      iter_cnt <= 0;
      done_reg <= 0;
    end else begin
      case (state)
        IDLE: begin
          done_reg <= 0;
          if (start) begin
            // load inputs into mem (sign-extend)
            for (i = 0; i < N; i = i + 1) begin
              mem_real[i] <= {{GAIN_W{data_real_in[i][DATA_W-1]}}, data_real_in[i]};
              mem_imag[i] <= {{GAIN_W{data_imag_in[i][DATA_W-1]}}, data_imag_in[i]};
            end
            iter_cnt <= 0;
            state    <= CALC;
          end
        end
        CALC: begin
          // perform one butterfly
          mem_real[p_idx] <= bf_p_re;
          mem_imag[p_idx] <= bf_p_im;
          mem_real[q_idx] <= bf_q_re;
          mem_imag[q_idx] <= bf_q_im;
          if (iter_cnt == (N/2 * 4 - 1)) begin
            state    <= DONE_ST;
            done_reg <= 1;
          end
          iter_cnt <= iter_cnt + 1;
        end
        DONE_ST: begin
          // hold results
          done_reg <= 1;
        end
        default: state <= IDLE;
      endcase
    end
  end

  // bit-reverse and final scaling (/16 -> arithmetic shift by GAIN_W)
  genvar gi;
  generate
    for (gi = 0; gi < N; gi = gi + 1) begin : GEN_OUT
      wire [3:0] br_idx;
      bit_reverse #(.WIDTH(4)) u_br (.in(gi[3:0]), .out(br_idx));
      assign data_real_out[gi] = mem_real[br_idx] >>> GAIN_W;
      assign data_imag_out[gi] = mem_imag[br_idx] >>> GAIN_W;
    end
  endgenerate

endmodule