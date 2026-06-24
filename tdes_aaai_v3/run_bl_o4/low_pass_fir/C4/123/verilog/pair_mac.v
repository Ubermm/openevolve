module pair_mac #(
    parameter DATA_W  = 20,
    parameter COEFF_W = 16
)(
    input  wire signed [DATA_W-1:0]  dataA,
    input  wire signed [DATA_W-1:0]  dataB,
    input  wire signed [COEFF_W-1:0] coeff,
    output wire signed [DATA_W+COEFF_W:0] product
);

    // Sign-extend inputs by one bit to prevent overflow on addition
    wire signed [DATA_W:0] dataA_ext = {dataA[DATA_W-1], dataA};
    wire signed [DATA_W:0] dataB_ext = {dataB[DATA_W-1], dataB};

    // Sum the two input samples
    wire signed [DATA_W:0] sum_ab = dataA_ext + dataB_ext;

    // Multiply the summed sample by the coefficient
    assign product = sum_ab * coeff;

endmodule