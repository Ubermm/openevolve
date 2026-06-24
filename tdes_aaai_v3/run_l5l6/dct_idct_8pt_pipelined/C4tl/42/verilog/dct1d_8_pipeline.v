`timescale 1ns/1ps

module dct1d_8_pipeline #(
    parameter DATA_W  = 12,
    parameter COEFF_W = 16,
    parameter OUT_W   = 18
) (
    input clk,
    input rst,
    input [DATA_W-1:0] sample_in,
    input valid_in,
    input mode, // 0 = DCT, 1 = IDCT
    input [2:0] index,
    output reg [OUT_W-1:0] coeff_out,
    output reg valid_out,
    output reg [2:0] index_out
);

    localparam PROD_W = DATA_W + COEFF_W;
    localparam SUM_W  = PROD_W + 4;

    reg signed [DATA_W-1:0] in_buf0, in_buf1, in_buf2, in_buf3;
    reg signed [DATA_W-1:0] in_buf4, in_buf5, in_buf6, in_buf7;

    reg signed [DATA_W-1:0] cur_buf0, cur_buf1, cur_buf2, cur_buf3;
    reg signed [DATA_W-1:0] cur_buf4, cur_buf5, cur_buf6, cur_buf7;

    reg signed [DATA_W-1:0] pend_buf0, pend_buf1, pend_buf2, pend_buf3;
    reg signed [DATA_W-1:0] pend_buf4, pend_buf5, pend_buf6, pend_buf7;

    reg out_active;
    reg launch_pending;
    reg pending_valid;
    reg out_mode;
    reg pending_mode;
    reg [2:0] out_idx;

    wire block_done;
    assign block_done = valid_in && (index == 3'd7);

    wire signed [DATA_W-1:0] sample_signed;
    assign sample_signed = $signed(sample_in);

    wire signed [DATA_W-1:0] eff0, eff1, eff2, eff3;
    wire signed [DATA_W-1:0] eff4, eff5, eff6, eff7;

    assign eff0 = (valid_in && (index == 3'd0)) ? sample_signed : in_buf0;
    assign eff1 = (valid_in && (index == 3'd1)) ? sample_signed : in_buf1;
    assign eff2 = (valid_in && (index == 3'd2)) ? sample_signed : in_buf2;
    assign eff3 = (valid_in && (index == 3'd3)) ? sample_signed : in_buf3;
    assign eff4 = (valid_in && (index == 3'd4)) ? sample_signed : in_buf4;
    assign eff5 = (valid_in && (index == 3'd5)) ? sample_signed : in_buf5;
    assign eff6 = (valid_in && (index == 3'd6)) ? sample_signed : in_buf6;
    assign eff7 = (valid_in && (index == 3'd7)) ? sample_signed : in_buf7;

    wire signed [COEFF_W-1:0] c0, c1, c2, c3, c4, c5, c6, c7;

    dct8_coeff_rom #(.COEFF_W(COEFF_W)) u_rom0 (
        .mode(out_mode), .out_index(out_idx), .in_index(3'd0), .coeff(c0)
    );
    dct8_coeff_rom #(.COEFF_W(COEFF_W)) u_rom1 (
        .mode(out_mode), .out_index(out_idx), .in_index(3'd1), .coeff(c1)
    );
    dct8_coeff_rom #(.COEFF_W(COEFF_W)) u_rom2 (
        .mode(out_mode), .out_index(out_idx), .in_index(3'd2), .coeff(c2)
    );
    dct8_coeff_rom #(.COEFF_W(COEFF_W)) u_rom3 (
        .mode(out_mode), .out_index(out_idx), .in_index(3'd3), .coeff(c3)
    );
    dct8_coeff_rom #(.COEFF_W(COEFF_W)) u_rom4 (
        .mode(out_mode), .out_index(out_idx), .in_index(3'd4), .coeff(c4)
    );
    dct8_coeff_rom #(.COEFF_W(COEFF_W)) u_rom5 (
        .mode(out_mode), .out_index(out_idx), .in_index(3'd5), .coeff(c5)
    );
    dct8_coeff_rom #(.COEFF_W(COEFF_W)) u_rom6 (
        .mode(out_mode), .out_index(out_idx), .in_index(3'd6), .coeff(c6)
    );
    dct8_coeff_rom #(.COEFF_W(COEFF_W)) u_rom7 (
        .mode(out_mode), .out_index(out_idx), .in_index(3'd7), .coeff(c7)
    );

    wire signed [PROD_W-1:0] p0, p1, p2, p3, p4, p5, p6, p7;

    dct8_signed_mult #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) u_mul0 (
        .sample(cur_buf0), .coeff(c0), .product(p0)
    );
    dct8_signed_mult #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) u_mul1 (
        .sample(cur_buf1), .coeff(c1), .product(p1)
    );
    dct8_signed_mult #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) u_mul2 (
        .sample(cur_buf2), .coeff(c2), .product(p2)
    );
    dct8_signed_mult #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) u_mul3 (
        .sample(cur_buf3), .coeff(c3), .product(p3)
    );
    dct8_signed_mult #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) u_mul4 (
        .sample(cur_buf4), .coeff(c4), .product(p4)
    );
    dct8_signed_mult #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) u_mul5 (
        .sample(cur_buf5), .coeff(c5), .product(p5)
    );
    dct8_signed_mult #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) u_mul6 (
        .sample(cur_buf6), .coeff(c6), .product(p6)
    );
    dct8_signed_mult #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) u_mul7 (
        .sample(cur_buf7), .coeff(c7), .product(p7)
    );

    wire signed [SUM_W-1:0] sum_full;

    dct8_adder_tree #(.PROD_W(PROD_W), .SUM_W(SUM_W)) u_adder (
        .p0(p0), .p1(p1), .p2(p2), .p3(p3),
        .p4(p4), .p5(p5), .p6(p6), .p7(p7),
        .sum_out(sum_full)
    );

    wire signed [OUT_W-1:0] rounded_sat;

    dct8_round_saturate #(
        .IN_W(SUM_W),
        .OUT_W(OUT_W),
        .SHIFT(COEFF_W-2)
    ) u_round_sat (
        .in_value(sum_full),
        .out_value(rounded_sat)
    );

    always @(posedge clk) begin
        if (rst) begin
            in_buf0 <= 0; in_buf1 <= 0; in_buf2 <= 0; in_buf3 <= 0;
            in_buf4 <= 0; in_buf5 <= 0; in_buf6 <= 0; in_buf7 <= 0;

            cur_buf0 <= 0; cur_buf1 <= 0; cur_buf2 <= 0; cur_buf3 <= 0;
            cur_buf4 <= 0; cur_buf5 <= 0; cur_buf6 <= 0; cur_buf7 <= 0;

            pend_buf0 <= 0; pend_buf1 <= 0; pend_buf2 <= 0; pend_buf3 <= 0;
            pend_buf4 <= 0; pend_buf5 <= 0; pend_buf6 <= 0; pend_buf7 <= 0;

            out_active     <= 1'b0;
            launch_pending <= 1'b0;
            pending_valid  <= 1'b0;
            out_mode       <= 1'b0;
            pending_mode   <= 1'b0;
            out_idx        <= 3'd0;

            coeff_out <= {OUT_W{1'b0}};
            valid_out <= 1'b0;
            index_out <= 3'd0;
        end else begin
            valid_out <= out_active;
            index_out <= out_idx;
            coeff_out <= rounded_sat;

            if (valid_in) begin
                case (index)
                    3'd0: in_buf0 <= sample_signed;
                    3'd1: in_buf1 <= sample_signed;
                    3'd2: in_buf2 <= sample_signed;
                    3'd3: in_buf3 <= sample_signed;
                    3'd4: in_buf4 <= sample_signed;
                    3'd5: in_buf5 <= sample_signed;
                    3'd6: in_buf6 <= sample_signed;
                    3'd7: in_buf7 <= sample_signed;
                    default: begin end
                endcase
            end

            if (out_active) begin
                if (out_idx == 3'd7) begin
                    if (block_done) begin
                        cur_buf0 <= eff0; cur_buf1 <= eff1; cur_buf2 <= eff2; cur_buf3 <= eff3;
                        cur_buf4 <= eff4; cur_buf5 <= eff5; cur_buf6 <= eff6; cur_buf7 <= eff7;
                        out_mode <= mode;
                        out_idx  <= 3'd0;
                        out_active <= 1'b1;
                    end else if (pending_valid) begin
                        cur_buf0 <= pend_buf0; cur_buf1 <= pend_buf1; cur_buf2 <= pend_buf2; cur_buf3 <= pend_buf3;
                        cur_buf4 <= pend_buf4; cur_buf5 <= pend_buf5; cur_buf6 <= pend_buf6; cur_buf7 <= pend_buf7;
                        out_mode <= pending_mode;
                        pending_valid <= 1'b0;
                        out_idx <= 3'd0;
                        out_active <= 1'b1;
                    end else if (launch_pending) begin
                        launch_pending <= 1'b0;
                        out_idx <= 3'd0;
                        out_active <= 1'b1;
                    end else begin
                        out_idx <= 3'd0;
                        out_active <= 1'b0;
                    end
                end else begin
                    out_idx <= out_idx + 3'd1;

                    if (block_done) begin
                        pend_buf0 <= eff0; pend_buf1 <= eff1; pend_buf2 <= eff2; pend_buf3 <= eff3;
                        pend_buf4 <= eff4; pend_buf5 <= eff5; pend_buf6 <= eff6; pend_buf7 <= eff7;
                        pending_mode  <= mode;
                        pending_valid <= 1'b1;
                    end
                end
            end else begin
                if (launch_pending) begin
                    launch_pending <= 1'b0;
                    out_active <= 1'b1;
                    out_idx <= 3'd0;
                end else if (block_done) begin
                    cur_buf0 <= eff0; cur_buf1 <= eff1; cur_buf2 <= eff2; cur_buf3 <= eff3;
                    cur_buf4 <= eff4; cur_buf5 <= eff5; cur_buf6 <= eff6; cur_buf7 <= eff7;
                    out_mode <= mode;
                    launch_pending <= 1'b1;
                    out_active <= 1'b0;
                    out_idx <= 3'd0;
                end
            end
        end
    end

endmodule