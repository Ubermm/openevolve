module scaler #(
    parameter integer ACC_W      = 64,
    parameter integer DATA_OUT_W = 24,
    parameter integer SHIFT      = 20
) (
    input  wire signed [ACC_W-1:0]    acc,
    output wire signed [DATA_OUT_W-1:0] out
);

    // Maximum and minimum representable output values
    localparam signed [DATA_OUT_W-1:0] MAX_VAL = {1'b0, {DATA_OUT_W-1{1'b1}}};
    localparam signed [DATA_OUT_W-1:0] MIN_VAL = {1'b1, {DATA_OUT_W-1{1'b0}}};

    // Corresponding accumulator thresholds for saturation
    localparam signed [ACC_W-1:0] MAX_ACC = MAX_VAL <<< SHIFT;
    localparam signed [ACC_W-1:0] MIN_ACC = MIN_VAL <<< SHIFT;

    // Arithmetic right-shift of accumulator
    wire signed [ACC_W-1:0] rs = acc >>> SHIFT;

    // Saturate or truncate result
    assign out = (acc > MAX_ACC) ? MAX_VAL :
                 (acc < MIN_ACC) ? MIN_VAL :
                                   rs[DATA_OUT_W-1:0];

endmodule