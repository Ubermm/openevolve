module fir_mac #(
    parameter DATA_W  = 20,
    parameter COEFF_W = 16,
    parameter SUM_W   = 64
) (
    input  wire signed [SUM_W-1:0]   sum_in,
    input  wire signed [DATA_W-1:0]  sample_in,
    input  wire signed [COEFF_W-1:0] coeff,
    output wire signed [SUM_W-1:0]   sum_out,
    output wire signed [DATA_W-1:0]  sample_out
);
    // Combinational multiply-accumulate for one FIR tap
    //   sum_out    = sum_in + (sample_in * coeff) [extended to SUM_W bits]
    //   sample_out = sample_in (pass-through for delay chain)

    // Multiply: produce (DATA_W + COEFF_W)-bit signed product
    wire signed [DATA_W+COEFF_W-1:0] mult;
    assign mult = sample_in * coeff;

    // Sign-extend the product to SUM_W bits
    wire signed [SUM_W-1:0] mult_ext;
    assign mult_ext = {{(SUM_W-(DATA_W+COEFF_W)){mult[DATA_W+COEFF_W-1]}}, mult};

    // Accumulate
    assign sum_out    = sum_in + mult_ext;
    // Pass the sample through for the shift register chain
    assign sample_out = sample_in;
endmodule