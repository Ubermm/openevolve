// Top-level IFFT16 iterative radix-2 fixed-point implementation
// Instantiates bit_reverse, twiddle_rom, butterfly_unit
module ifft16_iterative #(
    parameter N = 16,
    parameter DATA_W = 12,
    parameter COEFF_W = 16,
    parameter GAIN_W = 4
) (
    input clk,
    input rst,
    input start,
    input mode, // ignored, assume IFFT mode=1
    input  signed [DATA_W-1:0] data_real_in [0:N-1],
    input  signed [DATA_W-1:0] data_imag_in [0:N-1],
    output reg signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
    output reg signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
    output reg done
);
    // local parameters
    localparam OUT_W = DATA_W + GAIN_W;
    // memory for in-place computation
    reg signed [OUT_W-1:0] mem_real [0:N-1];
    reg signed [OUT_W-1:0] mem_imag [0:N-1];
    // FSM state
    typedef enum reg [1:0] {IDLE=0, LOAD=1, CALC=2, SCALE=3} state_t;
    reg state_t state;
    // stage counter (1..4)
    reg [2:0] stage_cnt;
    // butterfly index 0..7
    reg [3:0] bf_cnt;
    // computed indices
    reg [3:0] p_idx, q_idx;
    reg [3:0] tw_idx;
    // wires from twiddle ROM
    wire signed [COEFF_W-1:0] tw_cos, tw_sin;
    // outputs from butterfly
    wire signed [OUT_W-1:0] out0_re, out0_im, out1_re, out1_im;

    // instantiate twiddle lookup (conjugated table for IFFT)
    twiddle_rom #(.COEFF_W(COEFF_W)) twr (
        .tw_idx(tw_idx),
        .cos_q15(tw_cos),
        .sin_q15(tw_sin)
    );

    // instantiate butterfly unit (comb)
    butterfly_unit #(.DATA_W(DATA_W), .GAIN_W(GAIN_W), .COEFF_W(COEFF_W)) bf (
        .a_re(mem_real[p_idx]),
        .a_im(mem_imag[p_idx]),
        .b_re(mem_real[q_idx]),
        .b_im(mem_imag[q_idx]),
        .cos_q15(tw_cos),
        .sin_q15(tw_sin),
        .y0_re(out0_re),
        .y0_im(out0_im),
        .y1_re(out1_re),
        .y1_im(out1_im)
    );

    // bit-reversal for output mapping
    wire [3:0] rev_idx [0:N-1];
    genvar gi;
    generate
      for (gi=0; gi<N; gi=gi+1) begin : GEN_REV
        bit_reverse br(.din(gi[3:0]), .dout(rev_idx[gi]));
      end
    endgenerate

    // compute p_idx, q_idx, tw_idx combinationally
    // half_size = 1 << (stage_cnt-1)
    wire [3:0] half_size = 1 << (stage_cnt - 1);
    wire [3:0] block     = bf_cnt >> (stage_cnt - 1);
    wire [3:0] offset    = bf_cnt & (half_size - 1);
    wire [3:0] blk_sz    = half_size << 1;
    wire [3:0] tws       = N >> stage_cnt;
    always @* begin
      p_idx = (block << stage_cnt) + offset;
      q_idx = p_idx + half_size;
      tw_idx = offset * tws;
    end

    integer i;
    // FSM and registers
    always @(posedge clk) begin
      if (rst) begin
        state     <= IDLE;
        done      <= 1'b0;
        stage_cnt <= 3'd0;
        bf_cnt    <= 4'd0;
        // clear memory
        for (i=0; i<N; i=i+1) begin
          mem_real[i] <= {OUT_W{1'b0}};
          mem_imag[i] <= {OUT_W{1'b0}};
          data_real_out[i] <= {OUT_W{1'b0}};
          data_imag_out[i] <= {OUT_W{1'b0}};
        end
      end else begin
        case (state)
          IDLE: begin
            done <= 1'b0;
            if (start) begin
              state     <= LOAD;
            end
          end
          LOAD: begin
            // initial bit-reversed load
            for (i=0; i<N; i=i+1) begin
              mem_real[rev_idx[i]] <= data_real_in[i];
              mem_imag[rev_idx[i]] <= data_imag_in[i];
            end
            // init counters
            stage_cnt <= 3'd1;
            bf_cnt    <= 4'd0;
            state     <= CALC;
          end
          CALC: begin
            // perform one butterfly per cycle
            mem_real[p_idx] <= out0_re;
            mem_imag[p_idx] <= out0_im;
            mem_real[q_idx] <= out1_re;
            mem_imag[q_idx] <= out1_im;
            // next bf count
            if (bf_cnt == (N/2 - 1)) begin
              bf_cnt <= 4'd0;
              if (stage_cnt == $clog2(N)) begin
                state <= SCALE;
              end else begin
                stage_cnt <= stage_cnt + 1'b1;
              end
            end else begin
              bf_cnt <= bf_cnt + 1'b1;
            end
          end
          SCALE: begin
            // divide by N=16 arithmetic right shift by 4 and reorder out
            for (i=0; i<N; i=i+1) begin
              data_real_out[i] <= mem_real[rev_idx[i]] >>> GAIN_W;
              data_imag_out[i] <= mem_imag[rev_idx[i]] >>> GAIN_W;
            end
            done  <= 1'b1;
            state <= IDLE;
          end
        endcase
      end
    end
endmodule