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

    localparam OUT_W  = DATA_W + GAIN_W;
    localparam STAGES = 4;

    localparam S_IDLE = 2'd0;
    localparam S_RUN  = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state;
    reg [2:0] stage_cnt;
    reg [3:0] butterfly_cnt;
    reg mode_reg;

    reg signed [OUT_W-1:0] mem_real [0:N-1];
    reg signed [OUT_W-1:0] mem_imag [0:N-1];

    wire [3:0] p_idx;
    wire [3:0] q_idx;
    wire [3:0] tw_idx;

    wire signed [COEFF_W-1:0] tw_cos;
    wire signed [COEFF_W-1:0] tw_sin;

    wire signed [OUT_W-1:0] bf_p_real;
    wire signed [OUT_W-1:0] bf_p_imag;
    wire signed [OUT_W-1:0] bf_q_real;
    wire signed [OUT_W-1:0] bf_q_imag;

    wire [3:0] bitrev_idx [0:N-1];

    integer i;

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : GEN_BITREV
            localparam [3:0] GIDX = g[3:0];
            fft16_bit_reverse_index u_bit_reverse_index (
                .idx(GIDX),
                .rev(bitrev_idx[g])
            );
        end
    endgenerate

    fft16_index_calc #(
        .N(N)
    ) u_index_calc (
        .stage(stage_cnt),
        .butterfly(butterfly_cnt),
        .p_idx(p_idx),
        .q_idx(q_idx),
        .tw_idx(tw_idx)
    );

    fft16_twiddle_rom #(
        .COEFF_W(COEFF_W)
    ) u_twiddle_rom (
        .addr(tw_idx),
        .cos_q15(tw_cos),
        .sin_q15(tw_sin)
    );

    fft16_butterfly #(
        .X_W(OUT_W),
        .COEFF_W(COEFF_W)
    ) u_butterfly (
        .mode(mode_reg),
        .a_real(mem_real[p_idx]),
        .a_imag(mem_imag[p_idx]),
        .b_real(mem_real[q_idx]),
        .b_imag(mem_imag[q_idx]),
        .tw_cos(tw_cos),
        .tw_sin(tw_sin),
        .y0_real(bf_p_real),
        .y0_imag(bf_p_imag),
        .y1_real(bf_q_real),
        .y1_imag(bf_q_imag)
    );

    generate
        for (g = 0; g < N; g = g + 1) begin : GEN_OUTPUTS
            fft16_output_normalize #(
                .DATA_W(DATA_W),
                .GAIN_W(GAIN_W)
            ) u_output_norm_real (
                .mode(mode_reg),
                .din(mem_real[g]),
                .dout(data_real_out[g])
            );

            fft16_output_normalize #(
                .DATA_W(DATA_W),
                .GAIN_W(GAIN_W)
            ) u_output_norm_imag (
                .mode(mode_reg),
                .din(mem_imag[g]),
                .dout(data_imag_out[g])
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            stage_cnt <= 3'd0;
            butterfly_cnt <= 4'd0;
            mode_reg <= 1'b0;
            done <= 1'b0;

            for (i = 0; i < N; i = i + 1) begin
                mem_real[i] <= {OUT_W{1'b0}};
                mem_imag[i] <= {OUT_W{1'b0}};
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;

                    if (start) begin
                        mode_reg <= mode;
                        stage_cnt <= 3'd0;
                        butterfly_cnt <= 4'd0;
                        state <= S_RUN;

                        for (i = 0; i < N; i = i + 1) begin
                            mem_real[i] <= {{GAIN_W{data_real_in[bitrev_idx[i]][DATA_W-1]}},
                                            data_real_in[bitrev_idx[i]]};
                            mem_imag[i] <= {{GAIN_W{data_imag_in[bitrev_idx[i]][DATA_W-1]}},
                                            data_imag_in[bitrev_idx[i]]};
                        end
                    end
                end

                S_RUN: begin
                    done <= 1'b0;

                    mem_real[p_idx] <= bf_p_real;
                    mem_imag[p_idx] <= bf_p_imag;
                    mem_real[q_idx] <= bf_q_real;
                    mem_imag[q_idx] <= bf_q_imag;

                    if (butterfly_cnt == (N/2 - 1)) begin
                        butterfly_cnt <= 4'd0;

                        if (stage_cnt == (STAGES - 1)) begin
                            stage_cnt <= 3'd0;
                            state <= S_DONE;
                            done <= 1'b1;
                        end else begin
                            stage_cnt <= stage_cnt + 3'd1;
                        end
                    end else begin
                        butterfly_cnt <= butterfly_cnt + 4'd1;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;

                    if (start) begin
                        done <= 1'b0;
                        mode_reg <= mode;
                        stage_cnt <= 3'd0;
                        butterfly_cnt <= 4'd0;
                        state <= S_RUN;

                        for (i = 0; i < N; i = i + 1) begin
                            mem_real[i] <= {{GAIN_W{data_real_in[bitrev_idx[i]][DATA_W-1]}},
                                            data_real_in[bitrev_idx[i]]};
                            mem_imag[i] <= {{GAIN_W{data_imag_in[bitrev_idx[i]][DATA_W-1]}},
                                            data_imag_in[bitrev_idx[i]]};
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                    stage_cnt <= 3'd0;
                    butterfly_cnt <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule