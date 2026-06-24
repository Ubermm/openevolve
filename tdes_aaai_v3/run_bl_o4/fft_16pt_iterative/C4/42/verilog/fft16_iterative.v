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
    input signed [DATA_W-1:0] data_real_in  [0:N-1],
    input signed [DATA_W-1:0] data_imag_in  [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
    output                    done
);

localparam OUT_W = DATA_W + GAIN_W;
localparam STAGES = 4;
localparam BF_PER_STAGE = N/2;

// memory for in-place computation
reg signed [OUT_W-1:0] mem_real [0:N-1];
reg signed [OUT_W-1:0] mem_imag [0:N-1];

// control FSM
reg [1:0] stage_cnt;
reg [2:0] bf_cnt;
reg       computing;
reg       done_reg;

// detect last butterfly
wire last_bf = computing && (stage_cnt == STAGES-1) && (bf_cnt == BF_PER_STAGE-1);
assign done = done_reg;

// sequential control and memory writes
integer i;
always @(posedge clk) begin
    if (rst) begin
        computing <= 1'b0;
        stage_cnt <= 2'd0;
        bf_cnt    <= 3'd0;
        done_reg  <= 1'b0;
    end else begin
        if (start) begin
            // load inputs
            for (i = 0; i < N; i = i + 1) begin
                mem_real[i] <= {{GAIN_W{data_real_in[i][DATA_W-1]}}, data_real_in[i]};
                mem_imag[i] <= {{GAIN_W{data_imag_in[i][DATA_W-1]}}, data_imag_in[i]};
            end
            computing <= 1'b1;
            stage_cnt <= 2'd0;
            bf_cnt    <= 3'd0;
            done_reg  <= 1'b0;
        end else if (computing) begin
            if (bf_valid) begin
                // write butterfly outputs
                mem_real[p_addr] <= y_r_p;
                mem_imag[p_addr] <= y_i_p;
                mem_real[q_addr] <= y_r_q;
                mem_imag[q_addr] <= y_i_q;
                // next counters
                if (last_bf) begin
                    computing <= 1'b0;
                    done_reg  <= 1'b1;
                end
                if (bf_cnt == BF_PER_STAGE-1) begin
                    bf_cnt <= 3'd0;
                    stage_cnt <= stage_cnt + 1'b1;
                end else begin
                    bf_cnt <= bf_cnt + 1'b1;
                end
            end
        end
    end
end

wire bf_valid = computing;

// address and twiddle index generation
wire [3:0] p_addr, q_addr, tw_idx;
addr_gen addr_gen_i (
    .stage   (stage_cnt),
    .bf_cnt  (bf_cnt),
    .p_addr  (p_addr),
    .q_addr  (q_addr),
    .tw_idx  (tw_idx)
);

// twiddle ROM
wire signed [COEFF_W-1:0] cos_q, sin_q;
twiddle_rom tw_rom_i (
    .tw_idx  (tw_idx),
    .cos_q   (cos_q),
    .sin_q   (sin_q)
);

// read operands
wire signed [OUT_W-1:0] xr_p = mem_real[p_addr];
wire signed [OUT_W-1:0] xi_p = mem_imag[p_addr];
wire signed [OUT_W-1:0] xr_q = mem_real[q_addr];
wire signed [OUT_W-1:0] xi_q = mem_imag[q_addr];

// butterfly operation
wire signed [OUT_W-1:0] y_r_p, y_i_p, y_r_q, y_i_q;
butterfly_unit #(
    .DATA_W   (DATA_W),
    .COEFF_W  (COEFF_W),
    .GAIN_W   (GAIN_W)
) bf_i (
    .mode     (mode),
    .xr_p     (xr_p),
    .xi_p     (xi_p),
    .xr_q     (xr_q),
    .xi_q     (xi_q),
    .cos_q    (cos_q),
    .sin_q    (sin_q),
    .yr_p     (y_r_p),
    .yi_p     (y_i_p),
    .yr_q     (y_r_q),
    .yi_q     (y_i_q)
);

// outputs
genvar gi;
generate
    for (gi = 0; gi < N; gi = gi + 1) begin : OUT
        assign data_real_out[gi] = mem_real[gi];
        assign data_imag_out[gi] = mem_imag[gi];
    end
endgenerate

endmodule