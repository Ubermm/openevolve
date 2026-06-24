module bandpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4
) (
    input                       clk,
    input                       rst,
    input                       valid_in,
    input      [DATA_W-1:0]     data_in,
    output reg                  valid_out,
    output reg signed [DATA_W+GAIN_W-1:0] data_out
);
    // Parameters for sub-modules
    localparam COEFF_W = 16;
    localparam ADDR_W  = 7;   // enough to index 0..100
    localparam ACC_W   = 64;
    localparam PROD_W  = DATA_W + COEFF_W;

    // Delay-line of input samples (zero-padded when valid_in=0)
    reg signed [DATA_W-1:0] sample_reg [0:TAP_CNT-1];
    integer s;
    always @(posedge clk) begin
        if (rst) begin
            for (s = 0; s < TAP_CNT; s = s + 1)
                sample_reg[s] <= 0;
        end else begin
            // shift in new sample or zero
            sample_reg[0] <= valid_in ? $signed(data_in) : 0;
            for (s = 1; s < TAP_CNT; s = s + 1)
                sample_reg[s] <= sample_reg[s-1];
        end
    end

    // Products of samples and coefficients
    wire signed [PROD_W-1:0] products [0:TAP_CNT-1];
    genvar k;
    generate
        for (k = 0; k < TAP_CNT; k = k + 1) begin : mul_blk
            wire signed [COEFF_W-1:0] coeff_k;
            // Coefficient ROM
            coeff_rom #(
                .COEFF_W(COEFF_W),
                .ADDR_W(ADDR_W)
            ) rom_i (
                .addr(k[ADDR_W-1:0]),
                .coeff(coeff_k)
            );
            // Signed multiply
            signed_mult #(
                .DATA_W(DATA_W),
                .COEFF_W(COEFF_W)
            ) mul_i (
                .data_in(sample_reg[k]),
                .coeff(coeff_k),
                .product(products[k])
            );
        end
    endgenerate

    // Accumulate all products
    reg signed [ACC_W-1:0] acc;
    integer j;
    always @* begin
        acc = 0;
        for (j = 0; j < TAP_CNT; j = j + 1)
            acc = acc + products[j];
    end

    // Truncate and shift result
    wire signed [DATA_W+GAIN_W-1:0] truncated;
    trunc_shifter #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W+GAIN_W),
        .SHIFT(DATA_W)
    ) shft_i (
        .in_data(acc),
        .out_data(truncated)
    );

    // Output register and valid delay
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
            data_out  <= 0;
        end else begin
            valid_out <= valid_in;
            data_out  <= truncated;
        end
    end
endmodule