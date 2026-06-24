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
    output [OUT_W-1:0] coeff_out,
    output valid_out,
    output [2:0] index_out
);

    localparam ACC_W = DATA_W + COEFF_W + 4;
    localparam SHIFT = 14;

    reg signed [DATA_W-1:0] inbuf0;
    reg signed [DATA_W-1:0] inbuf1;
    reg signed [DATA_W-1:0] inbuf2;
    reg signed [DATA_W-1:0] inbuf3;
    reg signed [DATA_W-1:0] inbuf4;
    reg signed [DATA_W-1:0] inbuf5;
    reg signed [DATA_W-1:0] inbuf6;
    reg signed [DATA_W-1:0] inbuf7;

    reg signed [DATA_W-1:0] calc0;
    reg signed [DATA_W-1:0] calc1;
    reg signed [DATA_W-1:0] calc2;
    reg signed [DATA_W-1:0] calc3;
    reg signed [DATA_W-1:0] calc4;
    reg signed [DATA_W-1:0] calc5;
    reg signed [DATA_W-1:0] calc6;
    reg signed [DATA_W-1:0] calc7;

    reg        block_mode;
    reg        emitting;
    reg [2:0]  emit_idx;

    reg [OUT_W-1:0] coeff_out_r;
    reg             valid_out_r;
    reg [2:0]       index_out_r;

    wire signed [DATA_W-1:0] sample_signed;
    assign sample_signed = sample_in;

    wire signed [COEFF_W-1:0] c0;
    wire signed [COEFF_W-1:0] c1;
    wire signed [COEFF_W-1:0] c2;
    wire signed [COEFF_W-1:0] c3;
    wire signed [COEFF_W-1:0] c4;
    wire signed [COEFF_W-1:0] c5;
    wire signed [COEFF_W-1:0] c6;
    wire signed [COEFF_W-1:0] c7;

    wire signed [ACC_W-1:0] dot_acc;
    wire signed [OUT_W-1:0] rounded_sat;

    dct8_coeff_pack #(
        .COEFF_W(COEFF_W)
    ) u_coeff_pack (
        .mode(block_mode),
        .out_index(emit_idx),
        .c0(c0),
        .c1(c1),
        .c2(c2),
        .c3(c3),
        .c4(c4),
        .c5(c5),
        .c6(c6),
        .c7(c7)
    );

    dct8_dot_product #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_dot_product (
        .x0(calc0),
        .x1(calc1),
        .x2(calc2),
        .x3(calc3),
        .x4(calc4),
        .x5(calc5),
        .x6(calc6),
        .x7(calc7),
        .c0(c0),
        .c1(c1),
        .c2(c2),
        .c3(c3),
        .c4(c4),
        .c5(c5),
        .c6(c6),
        .c7(c7),
        .acc(dot_acc)
    );

    dct_round_saturate #(
        .ACC_W(ACC_W),
        .SHIFT(SHIFT),
        .OUT_W(OUT_W)
    ) u_round_saturate (
        .acc(dot_acc),
        .y(rounded_sat)
    );

    assign coeff_out = coeff_out_r;
    assign valid_out = valid_out_r;
    assign index_out = index_out_r;

    always @(posedge clk) begin
        if (rst) begin
            inbuf0      <= {DATA_W{1'b0}};
            inbuf1      <= {DATA_W{1'b0}};
            inbuf2      <= {DATA_W{1'b0}};
            inbuf3      <= {DATA_W{1'b0}};
            inbuf4      <= {DATA_W{1'b0}};
            inbuf5      <= {DATA_W{1'b0}};
            inbuf6      <= {DATA_W{1'b0}};
            inbuf7      <= {DATA_W{1'b0}};

            calc0       <= {DATA_W{1'b0}};
            calc1       <= {DATA_W{1'b0}};
            calc2       <= {DATA_W{1'b0}};
            calc3       <= {DATA_W{1'b0}};
            calc4       <= {DATA_W{1'b0}};
            calc5       <= {DATA_W{1'b0}};
            calc6       <= {DATA_W{1'b0}};
            calc7       <= {DATA_W{1'b0}};

            block_mode  <= 1'b0;
            emitting    <= 1'b0;
            emit_idx    <= 3'd0;

            coeff_out_r <= {OUT_W{1'b0}};
            valid_out_r <= 1'b0;
            index_out_r <= 3'd0;
        end else begin
            valid_out_r <= 1'b0;

            if (valid_in) begin
                case (index)
                    3'd0: inbuf0 <= sample_signed;
                    3'd1: inbuf1 <= sample_signed;
                    3'd2: inbuf2 <= sample_signed;
                    3'd3: inbuf3 <= sample_signed;
                    3'd4: inbuf4 <= sample_signed;
                    3'd5: inbuf5 <= sample_signed;
                    3'd6: inbuf6 <= sample_signed;
                    3'd7: inbuf7 <= sample_signed;
                    default: begin end
                endcase

                if (index == 3'd7) begin
                    calc0      <= inbuf0;
                    calc1      <= inbuf1;
                    calc2      <= inbuf2;
                    calc3      <= inbuf3;
                    calc4      <= inbuf4;
                    calc5      <= inbuf5;
                    calc6      <= inbuf6;
                    calc7      <= sample_signed;
                    block_mode <= mode;
                    emitting   <= 1'b1;
                    emit_idx   <= 3'd0;
                end
            end

            if (emitting) begin
                coeff_out_r <= rounded_sat;
                valid_out_r <= 1'b1;
                index_out_r <= emit_idx;

                if (emit_idx == 3'd7) begin
                    emitting <= 1'b0;
                    emit_idx <= 3'd0;
                end else begin
                    emit_idx <= emit_idx + 3'd1;
                end
            end
        end
    end

endmodule