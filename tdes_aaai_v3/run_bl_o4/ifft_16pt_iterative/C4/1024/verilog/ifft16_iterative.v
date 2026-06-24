// Top-level iterative 16-point IFFT (radix-2 DIT, fixed-point)
//
// Implements one butterfly per clock, log2(N)=4 stages, in-place RAM.
// Final output bit-reversed and scaled by N=16 (>>4).
//
module ifft16_iterative #(
    parameter N = 16,
    parameter DATA_W = 12,
    parameter COEFF_W = 16,
    parameter GAIN_W = 4
) (
    input clk,
    input rst,
    input start,
    input mode, // ignored, always IFFT
    input signed [DATA_W-1:0] data_real_in [0:N-1],
    input signed [DATA_W-1:0] data_imag_in [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_real_out [0:N-1],
    output signed [DATA_W+GAIN_W-1:0] data_imag_out [0:N-1],
    output done
);
    // local parameters
    localparam ADDR_W = $clog2(N);
    localparam OUT_W  = DATA_W + GAIN_W;
    localparam STAGES = $clog2(N);
    // state encoding
    localparam IDLE = 2'd0, CALC = 2'd1, DONE = 2'd2;
    // internal RAM
    reg signed [OUT_W-1:0] data_real [0:N-1];
    reg signed [OUT_W-1:0] data_imag [0:N-1];
    // control
    reg [1:0] state;
    reg [STAGES-1:0] stage;
    reg [ADDR_W-1:0] butterfly_cnt;
    reg done_reg;
    assign done = done_reg;
    // computed indices/wires for butterfly
    wire [ADDR_W-1:0] half_m      = (1 << stage);
    wire [ADDR_W-1:0] group       = butterfly_cnt / half_m;
    wire [ADDR_W-1:0] j_idx       = butterfly_cnt % half_m;
    wire [ADDR_W-1:0] p_addr      = (group << (stage+1)) + j_idx;
    wire [ADDR_W-1:0] q_addr      = p_addr + half_m;
    wire [ADDR_W-1:0] tw_step     = N >> (stage+1);
    wire [ADDR_W-1:0] twiddle_idx = j_idx * tw_step;
    // twiddle lookup
    wire signed [COEFF_W-1:0] cos_q15, sin_q15;
    twiddle_rom #( .COEFF_W(COEFF_W) ) rom (
        .addr(twiddle_idx),
        .cos_q15(cos_q15),
        .sin_q15(sin_q15)
    );
    // data for butterfly
    wire signed [OUT_W-1:0] xr = data_real[p_addr];
    wire signed [OUT_W-1:0] xi = data_imag[p_addr];
    wire signed [OUT_W-1:0] yr = data_real[q_addr];
    wire signed [OUT_W-1:0] yi = data_imag[q_addr];
    // butterfly outputs
    wire signed [OUT_W-1:0] out1_r, out1_i, out2_r, out2_i;
    butterfly_unit #(
        .DATA_W(OUT_W),
        .COEFF_W(COEFF_W)
    ) bfly (
        .xr(xr), .xi(xi),
        .yr(yr), .yi(yi),
        .cos_q15(cos_q15), .sin_q15(sin_q15),
        .out1_r(out1_r), .out1_i(out1_i),
        .out2_r(out2_r), .out2_i(out2_i)
    );
    // sequential FSM and RAM update
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            done_reg      <= 1'b0;
            stage         <= {STAGES{1'b0}};
            butterfly_cnt <= {ADDR_W{1'b0}};
            // clear memory
            for(i=0;i<N;i=i+1) begin
                data_real[i] <= {OUT_W{1'b0}};
                data_imag[i] <= {OUT_W{1'b0}};
            end
        end else begin
            case(state)
            IDLE: begin
                done_reg <= 1'b0;
                if (start) begin
                    // load inputs
                    for(i=0;i<N;i=i+1) begin
                        data_real[i] <= {{GAIN_W{data_real_in[i][DATA_W-1]}}, data_real_in[i]};
                        data_imag[i] <= {{GAIN_W{data_imag_in[i][DATA_W-1]}}, data_imag_in[i]};
                    end
                    stage         <= {STAGES{1'b0}};
                    butterfly_cnt <= {ADDR_W{1'b0}};
                    state         <= CALC;
                end
            end
            CALC: begin
                done_reg <= 1'b0;
                // perform butterfly and write back
                data_real[p_addr] <= out1_r;
                data_imag[p_addr] <= out1_i;
                data_real[q_addr] <= out2_r;
                data_imag[q_addr] <= out2_i;
                // counters
                if (butterfly_cnt == (N/2 - 1)) begin
                    butterfly_cnt <= {ADDR_W{1'b0}};
                    if (stage == STAGES-1) begin
                        state <= DONE;
                        stage <= {STAGES{1'b0}};
                    end else begin
                        stage <= stage + 1;
                    end
                end else begin
                    butterfly_cnt <= butterfly_cnt + 1;
                end
            end
            DONE: begin
                done_reg <= 1'b1;
                // stay DONE until reset
            end
            endcase
        end
    end
    // final output reordering and scaling
    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : out_gen
            wire [ADDR_W-1:0] rev;
            bit_rev #( .W(ADDR_W) ) brv (.in(gi[ADDR_W-1:0]), .out(rev));
            assign data_real_out[gi] = data_real[rev] >>> GAIN_W;
            assign data_imag_out[gi] = data_imag[rev] >>> GAIN_W;
        end
    endgenerate
endmodule