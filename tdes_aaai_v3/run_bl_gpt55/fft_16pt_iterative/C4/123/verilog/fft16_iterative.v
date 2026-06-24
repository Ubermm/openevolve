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

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            clog2 = 0;
            while (v > 0) begin
                v = v >> 1;
                clog2 = clog2 + 1;
            end
        end
    endfunction

    localparam LOGN  = clog2(N);
    localparam OUT_W = DATA_W + GAIN_W;

    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_LOAD = 2'd1;
    localparam [1:0] S_RUN  = 2'd2;
    localparam [1:0] S_DONE = 2'd3;

    reg [1:0] state;

    reg mode_reg;

    reg [LOGN-1:0] load_idx;
    reg [LOGN-1:0] stage_idx;
    reg [LOGN-1:0] bfly_idx;

    reg signed [OUT_W-1:0] mem_real [0:N-1];
    reg signed [OUT_W-1:0] mem_imag [0:N-1];

    wire [LOGN-1:0] load_bitrev_idx;

    wire [LOGN-1:0] p_idx;
    wire [LOGN-1:0] q_idx;
    wire [LOGN-1:0] tw_idx;
    wire idx_last_bfly;
    wire idx_last_stage;

    wire signed [COEFF_W-1:0] tw_cos;
    wire signed [COEFF_W-1:0] tw_sin;

    wire signed [OUT_W-1:0] bfly_y0_real;
    wire signed [OUT_W-1:0] bfly_y0_imag;
    wire signed [OUT_W-1:0] bfly_y1_real;
    wire signed [OUT_W-1:0] bfly_y1_imag;

    integer i;

    fft_bit_reverse_index #(
        .LOGN(LOGN)
    ) u_bit_reverse_index (
        .idx_in (load_idx),
        .idx_out(load_bitrev_idx)
    );

    fft_index_gen #(
        .N(N),
        .LOGN(LOGN)
    ) u_index_gen (
        .stage_idx     (stage_idx),
        .bfly_idx      (bfly_idx),
        .p_idx         (p_idx),
        .q_idx         (q_idx),
        .tw_idx        (tw_idx),
        .last_bfly     (idx_last_bfly),
        .last_stage    (idx_last_stage)
    );

    fft_twiddle_rom #(
        .N(N),
        .COEFF_W(COEFF_W),
        .LOGN(LOGN)
    ) u_twiddle_rom (
        .tw_idx(tw_idx),
        .cos_q (tw_cos),
        .sin_q (tw_sin)
    );

    fft_butterfly_fixed #(
        .DATA_W(OUT_W),
        .COEFF_W(COEFF_W)
    ) u_butterfly_fixed (
        .mode  (mode_reg),
        .a_real(mem_real[p_idx]),
        .a_imag(mem_imag[p_idx]),
        .b_real(mem_real[q_idx]),
        .b_imag(mem_imag[q_idx]),
        .tw_cos(tw_cos),
        .tw_sin(tw_sin),
        .y0_real(bfly_y0_real),
        .y0_imag(bfly_y0_imag),
        .y1_real(bfly_y1_real),
        .y1_imag(bfly_y1_imag)
    );

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            mode_reg  <= 1'b0;
            load_idx  <= {LOGN{1'b0}};
            stage_idx <= {LOGN{1'b0}};
            bfly_idx  <= {LOGN{1'b0}};
            for (i = 0; i < N; i = i + 1) begin
                mem_real[i] <= {OUT_W{1'b0}};
                mem_imag[i] <= {OUT_W{1'b0}};
            end
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        mode_reg  <= mode;
                        load_idx  <= {LOGN{1'b0}};
                        stage_idx <= {LOGN{1'b0}};
                        bfly_idx  <= {LOGN{1'b0}};
                        state     <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    mem_real[load_bitrev_idx] <= {{GAIN_W{data_real_in[load_idx][DATA_W-1]}}, data_real_in[load_idx]};
                    mem_imag[load_bitrev_idx] <= {{GAIN_W{data_imag_in[load_idx][DATA_W-1]}}, data_imag_in[load_idx]};

                    if (load_idx == N-1) begin
                        load_idx  <= {LOGN{1'b0}};
                        stage_idx <= {LOGN{1'b0}};
                        bfly_idx  <= {LOGN{1'b0}};
                        state     <= S_RUN;
                    end else begin
                        load_idx <= load_idx + {{(LOGN-1){1'b0}}, 1'b1};
                    end
                end

                S_RUN: begin
                    mem_real[p_idx] <= bfly_y0_real;
                    mem_imag[p_idx] <= bfly_y0_imag;
                    mem_real[q_idx] <= bfly_y1_real;
                    mem_imag[q_idx] <= bfly_y1_imag;

                    if (idx_last_bfly) begin
                        bfly_idx <= {LOGN{1'b0}};
                        if (idx_last_stage) begin
                            state <= S_DONE;
                        end else begin
                            stage_idx <= stage_idx + {{(LOGN-1){1'b0}}, 1'b1};
                        end
                    end else begin
                        bfly_idx <= bfly_idx + {{(LOGN-1){1'b0}}, 1'b1};
                    end
                end

                S_DONE: begin
                    if (start) begin
                        mode_reg  <= mode;
                        load_idx  <= {LOGN{1'b0}};
                        stage_idx <= {LOGN{1'b0}};
                        bfly_idx  <= {LOGN{1'b0}};
                        state     <= S_LOAD;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : GEN_OUTPUTS
            assign data_real_out[g] = mode_reg ? (mem_real[g] >>> LOGN) : mem_real[g];
            assign data_imag_out[g] = mode_reg ? (mem_imag[g] >>> LOGN) : mem_imag[g];
        end
    endgenerate

    assign done = (state == S_DONE);

endmodule