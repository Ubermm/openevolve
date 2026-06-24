`timescale 1ns/1ps
module fft16_iterative #(
    parameter N       = 16,
    parameter DATA_W  = 12,
    parameter COEFF_W = 16,
    parameter GAIN_W  = 4
) (
    input                         clk,
    input                         rst,
    input                         start,
    input                         mode, // 0: FFT, 1: IFFT
    input  signed [DATA_W-1:0]    data_real_in  [0:N-1],
    input  signed [DATA_W-1:0]    data_imag_in  [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
    output                        done
);

localparam OUT_W = DATA_W + GAIN_W;
localparam LOGN  = 4;

reg running;
reg signed [OUT_W-1:0] mem_re [0:N-1];
reg signed [OUT_W-1:0] mem_im [0:N-1];
reg [LOGN-1:0] stage;
reg [LOGN-1:0] cnt;
reg done_reg;

integer i;
wire [LOGN-1:0] cnt_mid = cnt;
wire [LOGN-1:0] stage_mid = stage;

// address generation
wire [LOGN-1:0] p, q;
wire [LOGN-1:0] tw_idx;
fft_addr_gen addr_gen (
    .stage(stage_mid[LOGN-1:1]==0 ? stage_mid[1:0] : stage_mid[1:0]), // use lower bits
    .cnt(cnt_mid[LOGN-1:0]),
    .addr_p(p),
    .addr_q(q),
    .tw_idx(tw_idx)
);

// twiddle ROM
wire signed [COEFF_W-1:0] tw_cos, tw_sin;
twiddle_rom_16 rom (
    .addr(tw_idx),
    .cos(tw_cos),
    .sin(tw_sin)
);

// adjust sin for IFFT mode
wire signed [COEFF_W-1:0] tw_sin_adj = mode ? -tw_sin : tw_sin;

// combinational read of current operands
wire signed [OUT_W-1:0] x0_re = mem_re[p];
wire signed [OUT_W-1:0] x0_im = mem_im[p];
wire signed [OUT_W-1:0] x1_re = mem_re[q];
wire signed [OUT_W-1:0] x1_im = mem_im[q];

// butterfly
wire signed [OUT_W-1:0] y0_re, y0_im, y1_re, y1_im;
fft_butterfly #(
    .WID   (OUT_W),
    .COEFF_W(COEFF_W)
) bf (
    .x0_re (x0_re),
    .x0_im (x0_im),
    .x1_re (x1_re),
    .x1_im (x1_im),
    .tw_cos(tw_cos),
    .tw_sin(tw_sin_adj),
    .y0_re (y0_re),
    .y0_im (y0_im),
    .y1_re (y1_re),
    .y1_im (y1_im)
);

// FSM & memory operations
always @(posedge clk) begin
    if (rst) begin
        running <= 1'b0;
        done_reg <= 1'b0;
        stage   <= {LOGN{1'b0}};
        cnt     <= {LOGN{1'b0}};
        // clear memory
        for (i = 0; i < N; i = i + 1) begin
            mem_re[i] <= {OUT_W{1'b0}};
            mem_im[i] <= {OUT_W{1'b0}};
        end
    end else if (!running && start) begin
        // load inputs
        running <= 1'b1;
        done_reg <= 1'b0;
        stage   <= {LOGN{1'b0}};
        cnt     <= {LOGN{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            mem_re[i] <= {{GAIN_W{data_real_in[i][DATA_W-1]}}, data_real_in[i]};
            mem_im[i] <= {{GAIN_W{data_imag_in[i][DATA_W-1]}}, data_imag_in[i]};
        end
    end else if (running) begin
        // perform one butterfly per cycle
        mem_re[p] <= y0_re;
        mem_re[q] <= y1_re;
        mem_im[p] <= y0_im;
        mem_im[q] <= y1_im;
        // next cnt/stage
        if (cnt == (N/2 - 1)) begin
            cnt <= {LOGN{1'b0}};
            if (stage == (LOGN-1)) begin
                running <= 1'b0;
                done_reg <= 1'b1;
            end else begin
                stage <= stage + 1'b1;
            end
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
end

// outputs
assign done = done_reg;
genvar gi;
generate
    for (gi = 0; gi < N; gi = gi + 1) begin : OUTP
        assign data_real_out[gi] = mem_re[gi];
        assign data_imag_out[gi] = mem_im[gi];
    end
endgenerate

endmodule