`timescale 1ns/1ps
module fft16_iterative #(
    parameter N = 16,
    parameter DATA_W = 12,
    parameter COEFF_W = 16,
    parameter GAIN_W = 4
) (
    input clk,
    input rst,
    input start,
    input mode, // 0: FFT, 1: IFFT
    input signed [DATA_W-1:0] data_real_in [0:N-1],
    input signed [DATA_W-1:0] data_imag_in [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
    output reg done
);
    // Internal parameters
    localparam OUT_W = DATA_W + GAIN_W;
    localparam LOG2N = 4;

    // FSM states
    localparam IDLE = 2'd0;
    localparam LOAD = 2'd1;
    localparam CALC = 2'd2;
    localparam DONE = 2'd3;

    // Internal memories for data
    reg signed [OUT_W-1:0] mem_real [0:N-1];
    reg signed [OUT_W-1:0] mem_imag [0:N-1];

    reg [1:0] state;
    reg [1:0] stage;
    reg [2:0] bcnt;

    // Address and twiddle wires
    wire [3:0] p_addr, q_addr, tw_addr;

    // Twiddle outputs
    wire signed [COEFF_W-1:0] cos_q15, sin_q15;

    // Instantiate address generator
    addr_gen addr_gen_i (
        .stage(stage),
        .bcnt(bcnt),
        .p_addr(p_addr),
        .q_addr(q_addr),
        .tw_addr(tw_addr)
    );

    // Instantiate twiddle ROM
    twiddle_rom tw_rom_i (
        .addr(tw_addr),
        .mode(mode),
        .cos_q15(cos_q15),
        .sin_q15(sin_q15)
    );

    // Data to butterfly
    wire signed [OUT_W-1:0] a_re = mem_real[p_addr];
    wire signed [OUT_W-1:0] a_im = mem_imag[p_addr];
    wire signed [OUT_W-1:0] b_re = mem_real[q_addr];
    wire signed [OUT_W-1:0] b_im = mem_imag[q_addr];

    // Butterfly outputs
    wire signed [OUT_W-1:0] y0_re, y0_im, y1_re, y1_im;
    butterfly #(
        .OUT_W(OUT_W),
        .COEFF_W(COEFF_W)
    ) bf_i (
        .a_re(a_re), .a_im(a_im),
        .b_re(b_re), .b_im(b_im),
        .cos_q15(cos_q15), .sin_q15(sin_q15),
        .y0_re(y0_re), .y0_im(y0_im),
        .y1_re(y1_re), .y1_im(y1_im)
    );

    integer i;
    // FSM
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                LOAD: begin
                    // Load inputs into memory
                    for (i = 0; i < N; i = i + 1) begin
                        mem_real[i] <= {{GAIN_W{data_real_in[i][DATA_W-1]}}, data_real_in[i]};
                        mem_imag[i] <= {{GAIN_W{data_imag_in[i][DATA_W-1]}}, data_imag_in[i]};
                    end
                    stage <= 2'd0;
                    bcnt  <= 3'd0;
                    state <= CALC;
                end
                CALC: begin
                    // Perform one butterfly
                    mem_real[p_addr] <= y0_re;
                    mem_imag[p_addr] <= y0_im;
                    mem_real[q_addr] <= y1_re;
                    mem_imag[q_addr] <= y1_im;
                    // Next counters
                    if (bcnt == (N/2-1)) begin
                        bcnt <= 3'd0;
                        if (stage == LOG2N-1) begin
                            state <= DONE;
                        end else begin
                            stage <= stage + 1;
                        end
                    end else begin
                        bcnt <= bcnt + 1;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    // Remain in DONE until reset
                end
            endcase
        end
    end

    // Output assignment with IFFT normalization
    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : OUT_ASSIGN
            // For IFFT, divide by N (=1<<GAIN_W)
            assign data_real_out[gi] = mode ? (mem_real[gi] >>> GAIN_W) : mem_real[gi];
            assign data_imag_out[gi] = mode ? (mem_imag[gi] >>> GAIN_W) : mem_imag[gi];
        end
    endgenerate

endmodule