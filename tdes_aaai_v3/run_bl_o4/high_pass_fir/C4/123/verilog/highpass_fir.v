// Top-level high-pass FIR filter, streaming, one sample per clock after latency
module highpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4
) (
    input                       clk,
    input                       rst,
    input                       valid_in,
    input      [DATA_W-1:0]     data_in,
    output                      valid_out,
    output     [DATA_W+GAIN_W-1:0] data_out
);

    // Intermediate widths
    localparam COEFF_W = 16;
    localparam OUT_W   = DATA_W + GAIN_W;       // 24
    localparam SHIFT   = 15;                    // Q15 coefficient scaling
    localparam ACC_W   = DATA_W + COEFF_W + 7;   // 20+16+7 = 43 bits to accumulate safely

    // shift register for input samples
    reg signed [DATA_W-1:0] data_mem [0:TAP_CNT-1];
    integer si;
    // valid pipeline
    reg [0:TAP_CNT] valid_pipe;
    integer vi;

    // coefficient wires
    wire signed [COEFF_W-1:0] coeffs [0:TAP_CNT-1];
    genvar ci;
    generate
        for (ci = 0; ci < TAP_CNT; ci = ci + 1) begin : GEN_COEFF
            fir_coeffs coeff_inst (
                .idx  (ci),
                .coeff(coeffs[ci])
            );
        end
    endgenerate

    // multiply outputs
    wire signed [DATA_W+COEFF_W-1:0] prods [0:TAP_CNT-1];
    genvar mi;
    generate
        for (mi = 0; mi < TAP_CNT; mi = mi + 1) begin : GEN_MULT
            mult_by_coeff #(
                .DATA_W (DATA_W),
                .COEFF_W(COEFF_W)
            ) m_inst (
                .data (data_mem[mi]),
                .coeff(coeffs[mi]),
                .prod (prods[mi])
            );
        end
    endgenerate

    // adder chain
    wire signed [ACC_W-1:0] sums [0:TAP_CNT-1];
    genvar ai;
    generate
        // first tap
        assign sums[0] = {{(ACC_W-(DATA_W+COEFF_W)){prods[0][DATA_W+COEFF_W-1]}}, prods[0]};
        for (ai = 1; ai < TAP_CNT; ai = ai + 1) begin : GEN_ADD
            adder #(.W(ACC_W)) add_inst (
                .a  (sums[ai-1]),
                .b  ({{(ACC_W-(DATA_W+COEFF_W)){prods[ai][DATA_W+COEFF_W-1]}},prods[ai]}),
                .sum(sums[ai])
            );
        end
    endgenerate

    // shift and saturate to output
    wire signed [OUT_W-1:0] shifted;
    output_shifter #(
        .IN_W (ACC_W),
        .OUT_W(OUT_W),
        .SHIFT(SHIFT)
    ) sh_inst (
        .in (sums[TAP_CNT-1]),
        .out(shifted)
    );

    // Sequential: shift register and valid pipeline
    always @(posedge clk) begin
        if (rst) begin
            for (si = 0; si < TAP_CNT; si = si + 1)
                data_mem[si] <= 0;
            valid_pipe <= 0;
        end else begin
            // shift sample memory
            data_mem[0] <= valid_in ? $signed(data_in) : 0;
            for (si = 1; si < TAP_CNT; si = si + 1)
                data_mem[si] <= data_mem[si-1];
            // valid pipeline
            valid_pipe[0] <= valid_in;
            for (vi = 0; vi < TAP_CNT; vi = vi + 1)
                valid_pipe[vi+1] <= valid_pipe[vi];
        end
    end

    assign valid_out = valid_pipe[TAP_CNT];
    assign data_out  = shifted;

endmodule