`timescale 1ns/1ps

module fft64_streaming #(
    parameter DATA_W = 16,
    parameter POINTS = 64,
    parameter GROWTH = 4
) (
    input clk,
    input rst,
    input signed [DATA_W-1:0] real_in,
    input signed [DATA_W-1:0] imag_in,
    input valid_in,
    input last_in,
    output signed [DATA_W+GROWTH-1:0] real_out,
    output signed [DATA_W+GROWTH-1:0] imag_out,
    output valid_out,
    output last_out,
    output done
);

    localparam OUT_W     = DATA_W + GROWTH;
    localparam STAGES    = 6;       // fixed FFT-64 streaming pipeline depth
    localparam TW_W      = 16;
    localparam CNT_W     = 6;

    // -------------------------------------------------------------------------
    // Input extension
    // -------------------------------------------------------------------------
    wire signed [OUT_W-1:0] in_re_ext;
    wire signed [OUT_W-1:0] in_im_ext;

    fft64_sign_extend #(
        .IN_W (DATA_W),
        .OUT_W(OUT_W)
    ) u_sign_extend (
        .in_re (real_in),
        .in_im (imag_in),
        .out_re(in_re_ext),
        .out_im(in_im_ext)
    );

    // -------------------------------------------------------------------------
    // Pipeline storage and control forwarding
    // -------------------------------------------------------------------------
    reg [STAGES-1:0] valid_pipe;
    reg [STAGES-1:0] last_pipe;

    reg [CNT_W-1:0] sample_cnt;
    reg [CNT_W-1:0] cnt_s1, cnt_s2, cnt_s3, cnt_s4, cnt_s5, cnt_s6;

    reg signed [OUT_W-1:0] dly0_re, dly0_im;
    reg signed [OUT_W-1:0] dly1_re, dly1_im;
    reg signed [OUT_W-1:0] dly2_re, dly2_im;
    reg signed [OUT_W-1:0] dly3_re, dly3_im;
    reg signed [OUT_W-1:0] dly4_re, dly4_im;
    reg signed [OUT_W-1:0] dly5_re, dly5_im;

    reg signed [OUT_W-1:0] s1_re, s1_im;
    reg signed [OUT_W-1:0] s2_re, s2_im;
    reg signed [OUT_W-1:0] s3_re, s3_im;
    reg signed [OUT_W-1:0] s4_re, s4_im;
    reg signed [OUT_W-1:0] s5_re, s5_im;
    reg signed [OUT_W-1:0] s6_re, s6_im;

    // -------------------------------------------------------------------------
    // Stage twiddle addressing
    // -------------------------------------------------------------------------
    wire [CNT_W-1:0] ph0 = sample_cnt;
    wire [CNT_W-1:0] ph1 = {cnt_s1[4:0], 1'b0};
    wire [CNT_W-1:0] ph2 = {cnt_s2[3:0], 2'b00};
    wire [CNT_W-1:0] ph3 = {cnt_s3[2:0], 3'b000};
    wire [CNT_W-1:0] ph4 = {cnt_s4[1:0], 4'b0000};
    wire [CNT_W-1:0] ph5 = {cnt_s5[0],   5'b00000};

    wire signed [TW_W-1:0] tw0_re, tw0_im;
    wire signed [TW_W-1:0] tw1_re, tw1_im;
    wire signed [TW_W-1:0] tw2_re, tw2_im;
    wire signed [TW_W-1:0] tw3_re, tw3_im;
    wire signed [TW_W-1:0] tw4_re, tw4_im;
    wire signed [TW_W-1:0] tw5_re, tw5_im;

    fft64_twiddle_rom #(.TW_W(TW_W)) u_tw0 (.addr(ph0), .tw_re(tw0_re), .tw_im(tw0_im));
    fft64_twiddle_rom #(.TW_W(TW_W)) u_tw1 (.addr(ph1), .tw_re(tw1_re), .tw_im(tw1_im));
    fft64_twiddle_rom #(.TW_W(TW_W)) u_tw2 (.addr(ph2), .tw_re(tw2_re), .tw_im(tw2_im));
    fft64_twiddle_rom #(.TW_W(TW_W)) u_tw3 (.addr(ph3), .tw_re(tw3_re), .tw_im(tw3_im));
    fft64_twiddle_rom #(.TW_W(TW_W)) u_tw4 (.addr(ph4), .tw_re(tw4_re), .tw_im(tw4_im));
    fft64_twiddle_rom #(.TW_W(TW_W)) u_tw5 (.addr(ph5), .tw_re(tw5_re), .tw_im(tw5_im));

    // -------------------------------------------------------------------------
    // Combinational datapath for six radix-style pipeline stages
    // -------------------------------------------------------------------------
    wire signed [OUT_W-1:0] m0_re, m0_im;
    wire signed [OUT_W-1:0] m1_re, m1_im;
    wire signed [OUT_W-1:0] m2_re, m2_im;
    wire signed [OUT_W-1:0] m3_re, m3_im;
    wire signed [OUT_W-1:0] m4_re, m4_im;
    wire signed [OUT_W-1:0] m5_re, m5_im;

    fft64_complex_mult #(.W(OUT_W), .TW_W(TW_W)) u_mul0 (
        .a_re(in_re_ext), .a_im(in_im_ext),
        .b_re(tw0_re),   .b_im(tw0_im),
        .p_re(m0_re),    .p_im(m0_im)
    );

    fft64_complex_mult #(.W(OUT_W), .TW_W(TW_W)) u_mul1 (
        .a_re(s1_re),  .a_im(s1_im),
        .b_re(tw1_re), .b_im(tw1_im),
        .p_re(m1_re),  .p_im(m1_im)
    );

    fft64_complex_mult #(.W(OUT_W), .TW_W(TW_W)) u_mul2 (
        .a_re(s2_re),  .a_im(s2_im),
        .b_re(tw2_re), .b_im(tw2_im),
        .p_re(m2_re),  .p_im(m2_im)
    );

    fft64_complex_mult #(.W(OUT_W), .TW_W(TW_W)) u_mul3 (
        .a_re(s3_re),  .a_im(s3_im),
        .b_re(tw3_re), .b_im(tw3_im),
        .p_re(m3_re),  .p_im(m3_im)
    );

    fft64_complex_mult #(.W(OUT_W), .TW_W(TW_W)) u_mul4 (
        .a_re(s4_re),  .a_im(s4_im),
        .b_re(tw4_re), .b_im(tw4_im),
        .p_re(m4_re),  .p_im(m4_im)
    );

    fft64_complex_mult #(.W(OUT_W), .TW_W(TW_W)) u_mul5 (
        .a_re(s5_re),  .a_im(s5_im),
        .b_re(tw5_re), .b_im(tw5_im),
        .p_re(m5_re),  .p_im(m5_im)
    );

    wire signed [OUT_W-1:0] b0_re, b0_im;
    wire signed [OUT_W-1:0] b1_re, b1_im;
    wire signed [OUT_W-1:0] b2_re, b2_im;
    wire signed [OUT_W-1:0] b3_re, b3_im;
    wire signed [OUT_W-1:0] b4_re, b4_im;
    wire signed [OUT_W-1:0] b5_re, b5_im;

    fft64_butterfly #(.W(OUT_W)) u_bfly0 (
        .x_re(dly0_re), .x_im(dly0_im),
        .y_re(m0_re),   .y_im(m0_im),
        .sub (sample_cnt[0]),
        .out_re(b0_re), .out_im(b0_im)
    );

    fft64_butterfly #(.W(OUT_W)) u_bfly1 (
        .x_re(dly1_re), .x_im(dly1_im),
        .y_re(m1_re),   .y_im(m1_im),
        .sub (cnt_s1[1]),
        .out_re(b1_re), .out_im(b1_im)
    );

    fft64_butterfly #(.W(OUT_W)) u_bfly2 (
        .x_re(dly2_re), .x_im(dly2_im),
        .y_re(m2_re),   .y_im(m2_im),
        .sub (cnt_s2[2]),
        .out_re(b2_re), .out_im(b2_im)
    );

    fft64_butterfly #(.W(OUT_W)) u_bfly3 (
        .x_re(dly3_re), .x_im(dly3_im),
        .y_re(m3_re),   .y_im(m3_im),
        .sub (cnt_s3[3]),
        .out_re(b3_re), .out_im(b3_im)
    );

    fft64_butterfly #(.W(OUT_W)) u_bfly4 (
        .x_re(dly4_re), .x_im(dly4_im),
        .y_re(m4_re),   .y_im(m4_im),
        .sub (cnt_s4[4]),
        .out_re(b4_re), .out_im(b4_im)
    );

    fft64_butterfly #(.W(OUT_W)) u_bfly5 (
        .x_re(dly5_re), .x_im(dly5_im),
        .y_re(m5_re),   .y_im(m5_im),
        .sub (cnt_s5[5]),
        .out_re(b5_re), .out_im(b5_im)
    );

    // -------------------------------------------------------------------------
    // Output formatting
    // -------------------------------------------------------------------------
    fft64_output_clip #(
        .IN_W (OUT_W),
        .OUT_W(OUT_W)
    ) u_output_clip (
        .in_re (s6_re),
        .in_im (s6_im),
        .out_re(real_out),
        .out_im(imag_out)
    );

    assign valid_out = valid_pipe[STAGES-1];
    assign last_out  = last_pipe [STAGES-1];
    assign done      = valid_out & last_out;

    // -------------------------------------------------------------------------
    // Sequential pipeline
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            valid_pipe <= {STAGES{1'b0}};
            last_pipe  <= {STAGES{1'b0}};

            sample_cnt <= {CNT_W{1'b0}};
            cnt_s1 <= {CNT_W{1'b0}};
            cnt_s2 <= {CNT_W{1'b0}};
            cnt_s3 <= {CNT_W{1'b0}};
            cnt_s4 <= {CNT_W{1'b0}};
            cnt_s5 <= {CNT_W{1'b0}};
            cnt_s6 <= {CNT_W{1'b0}};

            dly0_re <= {OUT_W{1'b0}}; dly0_im <= {OUT_W{1'b0}};
            dly1_re <= {OUT_W{1'b0}}; dly1_im <= {OUT_W{1'b0}};
            dly2_re <= {OUT_W{1'b0}}; dly2_im <= {OUT_W{1'b0}};
            dly3_re <= {OUT_W{1'b0}}; dly3_im <= {OUT_W{1'b0}};
            dly4_re <= {OUT_W{1'b0}}; dly4_im <= {OUT_W{1'b0}};
            dly5_re <= {OUT_W{1'b0}}; dly5_im <= {OUT_W{1'b0}};

            s1_re <= {OUT_W{1'b0}}; s1_im <= {OUT_W{1'b0}};
            s2_re <= {OUT_W{1'b0}}; s2_im <= {OUT_W{1'b0}};
            s3_re <= {OUT_W{1'b0}}; s3_im <= {OUT_W{1'b0}};
            s4_re <= {OUT_W{1'b0}}; s4_im <= {OUT_W{1'b0}};
            s5_re <= {OUT_W{1'b0}}; s5_im <= {OUT_W{1'b0}};
            s6_re <= {OUT_W{1'b0}}; s6_im <= {OUT_W{1'b0}};
        end else begin
            valid_pipe <= {valid_pipe[STAGES-2:0], valid_in};
            last_pipe  <= {last_pipe [STAGES-2:0], last_in};

            if (valid_in) begin
                if (last_in)
                    sample_cnt <= {CNT_W{1'b0}};
                else
                    sample_cnt <= sample_cnt + {{(CNT_W-1){1'b0}}, 1'b1};
            end

            // Stage 0 capture
            dly0_re <= in_re_ext;
            dly0_im <= in_im_ext;
            s1_re   <= b0_re;
            s1_im   <= b0_im;
            cnt_s1  <= sample_cnt;

            // Stage 1 capture
            dly1_re <= s1_re;
            dly1_im <= s1_im;
            s2_re   <= b1_re;
            s2_im   <= b1_im;
            cnt_s2  <= cnt_s1;

            // Stage 2 capture
            dly2_re <= s2_re;
            dly2_im <= s2_im;
            s3_re   <= b2_re;
            s3_im   <= b2_im;
            cnt_s3  <= cnt_s2;

            // Stage 3 capture
            dly3_re <= s3_re;
            dly3_im <= s3_im;
            s4_re   <= b3_re;
            s4_im   <= b3_im;
            cnt_s4  <= cnt_s3;

            // Stage 4 capture
            dly4_re <= s4_re;
            dly4_im <= s4_im;
            s5_re   <= b4_re;
            s5_im   <= b4_im;
            cnt_s5  <= cnt_s4;

            // Stage 5 capture
            dly5_re <= s5_re;
            dly5_im <= s5_im;
            s6_re   <= b5_re;
            s6_im   <= b5_im;
            cnt_s6  <= cnt_s5;
        end
    end

endmodule