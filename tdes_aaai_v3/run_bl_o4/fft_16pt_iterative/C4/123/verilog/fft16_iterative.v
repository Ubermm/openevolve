`timescale 1ns/1ps
module fft16_iterative #(
    parameter N = 16,
    parameter DATA_W = 12,
    parameter COEFF_W = 16,
    parameter GAIN_W = 4
) (
    input                     clk,
    input                     rst,
    input                     start,
    input                     mode, // 0: FFT, 1: IFFT
    input  signed [DATA_W-1:0] data_real_in  [0:N-1],
    input  signed [DATA_W-1:0] data_imag_in  [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
    output reg                done
);

localparam OUT_W = DATA_W + GAIN_W;

reg signed [OUT_W-1:0] mem_real [0:N-1];
reg signed [OUT_W-1:0] mem_imag [0:N-1];

reg [1:0] state;
localparam IDLE=2'd0, LOAD=2'd1, CALC=2'd2, DONE_S=2'd3;
reg [1:0] stage;
reg [2:0] but_idx;

// compute p,q,tw index
wire [3:0] m = (1 << stage);
wire [3:0] j = but_idx & (m-1);
wire [3:0] grp = but_idx >> stage;
wire [3:0] p_idx = grp * (2*m) + j;
wire [3:0] q_idx = p_idx + m;
wire [3:0] tw_base = N / (2*m);
wire [3:0] tw_idx = j * tw_base;

// twiddle lookup
wire signed [COEFF_W-1:0] cos_w, sin_w;
twiddle_rom #(.COEFF_W(COEFF_W)) rom (
    .idx(tw_idx), .cos_o(cos_w), .sin_o(sin_w)
);

// four butterfly instances
// stage 0: IN_W=DATA_W=12
wire signed [DATA_W:0]  b0_pr, b0_pi, b0_qr, b0_qi;
butterfly #(.IN_W(DATA_W), .COEFF_W(COEFF_W)) bf0 (
    .xr(mem_real[p_idx][DATA_W-1:0]), .xi(mem_imag[p_idx][DATA_W-1:0]),
    .yr(mem_real[q_idx][DATA_W-1:0]), .yi(mem_imag[q_idx][DATA_W-1:0]),
    .cos_w(cos_w), .sin_w(sin_w), .mode(mode),
    .p_r(b0_pr), .p_i(b0_pi), .q_r(b0_qr), .q_i(b0_qi)
);
// stage 1: IN_W=DATA_W+1
wire signed [DATA_W+1:0]  b1_pr, b1_pi, b1_qr, b1_qi;
butterfly #(.IN_W(DATA_W+1), .COEFF_W(COEFF_W)) bf1 (
    .xr(mem_real[p_idx][DATA_W  :0]), .xi(mem_imag[p_idx][DATA_W  :0]),
    .yr(mem_real[q_idx][DATA_W  :0]), .yi(mem_imag[q_idx][DATA_W  :0]),
    .cos_w(cos_w), .sin_w(sin_w), .mode(mode),
    .p_r(b1_pr), .p_i(b1_pi), .q_r(b1_qr), .q_i(b1_qi)
);
// stage 2: IN_W=DATA_W+2
wire signed [DATA_W+2:0]  b2_pr, b2_pi, b2_qr, b2_qi;
butterfly #(.IN_W(DATA_W+2), .COEFF_W(COEFF_W)) bf2 (
    .xr(mem_real[p_idx][DATA_W+1:0]), .xi(mem_imag[p_idx][DATA_W+1:0]),
    .yr(mem_real[q_idx][DATA_W+1:0]), .yi(mem_imag[q_idx][DATA_W+1:0]),
    .cos_w(cos_w), .sin_w(sin_w), .mode(mode),
    .p_r(b2_pr), .p_i(b2_pi), .q_r(b2_qr), .q_i(b2_qi)
);
// stage 3: IN_W=DATA_W+3
wire signed [DATA_W+3:0]  b3_pr, b3_pi, b3_qr, b3_qi;
butterfly #(.IN_W(DATA_W+3), .COEFF_W(COEFF_W)) bf3 (
    .xr(mem_real[p_idx][DATA_W+2:0]), .xi(mem_imag[p_idx][DATA_W+2:0]),
    .yr(mem_real[q_idx][DATA_W+2:0]), .yi(mem_imag[q_idx][DATA_W+2:0]),
    .cos_w(cos_w), .sin_w(sin_w), .mode(mode),
    .p_r(b3_pr), .p_i(b3_pi), .q_r(b3_qr), .q_i(b3_qi)
);

// pack selected butterfly outputs
reg signed [OUT_W-1:0] w_pr, w_pi, w_qr, w_qi;
integer i;
always @(*) begin
    w_pr = 0; w_pi = 0; w_qr = 0; w_qi = 0;
    case(stage)
      2'd0: begin
        // b0 outputs are [DATA_W:0]
        w_pr = {{(OUT_W-(DATA_W+1)){b0_pr[DATA_W]}}, b0_pr};
        w_pi = {{(OUT_W-(DATA_W+1)){b0_pi[DATA_W]}}, b0_pi};
        w_qr = {{(OUT_W-(DATA_W+1)){b0_qr[DATA_W]}}, b0_qr};
        w_qi = {{(OUT_W-(DATA_W+1)){b0_qi[DATA_W]}}, b0_qi};
      end
      2'd1: begin
        w_pr = {{(OUT_W-(DATA_W+2)){b1_pr[DATA_W+1]}}, b1_pr};
        w_pi = {{(OUT_W-(DATA_W+2)){b1_pi[DATA_W+1]}}, b1_pi};
        w_qr = {{(OUT_W-(DATA_W+2)){b1_qr[DATA_W+1]}}, b1_qr};
        w_qi = {{(OUT_W-(DATA_W+2)){b1_qi[DATA_W+1]}}, b1_qi};
      end
      2'd2: begin
        w_pr = {{(OUT_W-(DATA_W+3)){b2_pr[DATA_W+2]}}, b2_pr};
        w_pi = {{(OUT_W-(DATA_W+3)){b2_pi[DATA_W+2]}}, b2_pi};
        w_qr = {{(OUT_W-(DATA_W+3)){b2_qr[DATA_W+2]}}, b2_qr};
        w_qi = {{(OUT_W-(DATA_W+3)){b2_qi[DATA_W+2]}}, b2_qi};
      end
      2'd3: begin
        w_pr = {{(OUT_W-(DATA_W+4)){b3_pr[DATA_W+3]}}, b3_pr};
        w_pi = {{(OUT_W-(DATA_W+4)){b3_pi[DATA_W+3]}}, b3_pi};
        w_qr = {{(OUT_W-(DATA_W+4)){b3_qr[DATA_W+3]}}, b3_qr};
        w_qi = {{(OUT_W-(DATA_W+4)){b3_qi[DATA_W+3]}}, b3_qi};
      end
      default: ;
    endcase
end

// state machine and memory update
always @(posedge clk) begin
    if (rst) begin
        state   <= IDLE;
        done    <= 1'b0;
        stage   <= 2'd0;
        but_idx <= 3'd0;
    end else begin
        case (state)
        IDLE: begin
            done <= 1'b0;
            if (start) state <= LOAD;
        end
        LOAD: begin
            // load inputs
            for (i=0; i<N; i=i+1) begin
                mem_real[i] <= {{GAIN_W{data_real_in[i][DATA_W-1]}}, data_real_in[i]};
                mem_imag[i] <= {{GAIN_W{data_imag_in[i][DATA_W-1]}}, data_imag_in[i]};
            end
            stage   <= 2'd0;
            but_idx <= 3'd0;
            state   <= CALC;
        end
        CALC: begin
            // write back butterfly results
            mem_real[p_idx] <= w_pr;
            mem_imag[p_idx] <= w_pi;
            mem_real[q_idx] <= w_qr;
            mem_imag[q_idx] <= w_qi;
            // next butterfly
            if (but_idx == (N/2 - 1)) begin
                but_idx <= 3'd0;
                if (stage == ( ($clog2(N)) - 1 )) begin
                    state <= DONE_S;
                    done  <= 1'b1;
                end else begin
                    stage <= stage + 2'd1;
                end
            end else begin
                but_idx <= but_idx + 3'd1;
            end
        end
        DONE_S: begin
            // stay here until reset
        end
        endcase
    end
end

// bit-reversal and final output (with IFFT scaling)
genvar gi;
generate
  for (gi=0; gi<N; gi=gi+1) begin : OUT
    wire [3:0] rev = bit_rev4(gi);
    wire signed [OUT_W-1:0] vr = mem_real[rev];
    wire signed [OUT_W-1:0] vi = mem_imag[rev];
    // scaling for IFFT
    assign data_real_out[gi] = mode ? (vr >>> GAIN_W) : vr;
    assign data_imag_out[gi] = mode ? (vi >>> GAIN_W) : vi;
  end
endgenerate

// simple function for 4-bit reversal
function [3:0] bit_rev4(input [3:0] in);
    bit_rev4[3] = in[0];
    bit_rev4[2] = in[1];
    bit_rev4[1] = in[2];
    bit_rev4[0] = in[3];
endfunction

endmodule