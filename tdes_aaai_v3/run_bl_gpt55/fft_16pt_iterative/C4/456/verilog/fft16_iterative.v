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
    output done
);

    localparam OUT_W  = DATA_W + GAIN_W;
    localparam ADDR_W = 4;
    localparam LOGN   = 4;

    localparam S_IDLE = 2'd0;
    localparam S_CALC = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state;
    reg [1:0] stage;
    reg [2:0] butterfly_idx;
    reg mode_reg;
    reg done_reg;

    assign done = done_reg;

    reg signed [OUT_W-1:0] mem_real [0:N-1];
    reg signed [OUT_W-1:0] mem_imag [0:N-1];

    wire [ADDR_W-1:0] p_addr;
    wire [ADDR_W-1:0] q_addr;
    wire [ADDR_W-1:0] tw_addr;

    wire signed [COEFF_W-1:0] tw_cos;
    wire signed [COEFF_W-1:0] tw_sin;

    wire signed [OUT_W-1:0] bf_y0_real;
    wire signed [OUT_W-1:0] bf_y0_imag;
    wire signed [OUT_W-1:0] bf_y1_real;
    wire signed [OUT_W-1:0] bf_y1_imag;

    wire [ADDR_W-1:0] load_br_addr [0:N-1];

    genvar gi;

    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : GEN_BITREV
            wire [ADDR_W-1:0] idx_const;
            assign idx_const = gi[ADDR_W-1:0];

            fft16_bit_reverse #(
                .ADDR_W(ADDR_W)
            ) u_bit_reverse (
                .addr_in (idx_const),
                .addr_out(load_br_addr[gi])
            );
        end
    endgenerate

    fft16_addr_gen #(
        .N(N),
        .ADDR_W(ADDR_W)
    ) u_addr_gen (
        .stage        (stage),
        .butterfly_idx(butterfly_idx),
        .p_addr       (p_addr),
        .q_addr       (q_addr),
        .tw_addr      (tw_addr)
    );

    fft16_twiddle_rom #(
        .COEFF_W(COEFF_W),
        .ADDR_W(ADDR_W)
    ) u_twiddle_rom (
        .tw_addr(tw_addr),
        .cos_q15(tw_cos),
        .sin_q15(tw_sin)
    );

    fft16_butterfly #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .GAIN_W(GAIN_W)
    ) u_butterfly (
        .mode    (mode_reg),
        .x0_real (mem_real[p_addr]),
        .x0_imag (mem_imag[p_addr]),
        .x1_real (mem_real[q_addr]),
        .x1_imag (mem_imag[q_addr]),
        .cos_q15 (tw_cos),
        .sin_q15 (tw_sin),
        .y0_real (bf_y0_real),
        .y0_imag (bf_y0_imag),
        .y1_real (bf_y1_real),
        .y1_imag (bf_y1_imag)
    );

    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : GEN_OUTPUT_SCALE
            fft16_output_scale #(
                .DATA_W(DATA_W),
                .GAIN_W(GAIN_W)
            ) u_scale_real (
                .mode(mode_reg),
                .din (mem_real[gi]),
                .dout(data_real_out[gi])
            );

            fft16_output_scale #(
                .DATA_W(DATA_W),
                .GAIN_W(GAIN_W)
            ) u_scale_imag (
                .mode(mode_reg),
                .din (mem_imag[gi]),
                .dout(data_imag_out[gi])
            );
        end
    endgenerate

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            state         <= S_IDLE;
            stage         <= 2'd0;
            butterfly_idx <= 3'd0;
            mode_reg      <= 1'b0;
            done_reg      <= 1'b0;

            for (i = 0; i < N; i = i + 1) begin
                mem_real[i] <= {OUT_W{1'b0}};
                mem_imag[i] <= {OUT_W{1'b0}};
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done_reg <= 1'b0;

                    if (start) begin
                        mode_reg      <= mode;
                        stage         <= 2'd0;
                        butterfly_idx <= 3'd0;
                        state         <= S_CALC;

                        for (i = 0; i < N; i = i + 1) begin
                            mem_real[i] <= {{GAIN_W{data_real_in[load_br_addr[i]][DATA_W-1]}},
                                            data_real_in[load_br_addr[i]]};
                            mem_imag[i] <= {{GAIN_W{data_imag_in[load_br_addr[i]][DATA_W-1]}},
                                            data_imag_in[load_br_addr[i]]};
                        end
                    end
                end

                S_CALC: begin
                    mem_real[p_addr] <= bf_y0_real;
                    mem_imag[p_addr] <= bf_y0_imag;
                    mem_real[q_addr] <= bf_y1_real;
                    mem_imag[q_addr] <= bf_y1_imag;

                    if (butterfly_idx == 3'd7) begin
                        butterfly_idx <= 3'd0;

                        if (stage == 2'd3) begin
                            state    <= S_DONE;
                            done_reg <= 1'b1;
                        end else begin
                            stage <= stage + 2'd1;
                        end
                    end else begin
                        butterfly_idx <= butterfly_idx + 3'd1;
                    end
                end

                S_DONE: begin
                    done_reg <= 1'b1;

                    if (start) begin
                        done_reg      <= 1'b0;
                        mode_reg      <= mode;
                        stage         <= 2'd0;
                        butterfly_idx <= 3'd0;
                        state         <= S_CALC;

                        for (i = 0; i < N; i = i + 1) begin
                            mem_real[i] <= {{GAIN_W{data_real_in[load_br_addr[i]][DATA_W-1]}},
                                            data_real_in[load_br_addr[i]]};
                            mem_imag[i] <= {{GAIN_W{data_imag_in[load_br_addr[i]][DATA_W-1]}},
                                            data_imag_in[load_br_addr[i]]};
                        end
                    end
                end

                default: begin
                    state    <= S_IDLE;
                    done_reg <= 1'b0;
                end
            endcase
        end
    end

endmodule