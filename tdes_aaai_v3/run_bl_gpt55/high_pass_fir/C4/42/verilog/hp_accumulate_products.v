`timescale 1ns/1ps

module hp_accumulate_products #(
    parameter TAP_CNT = 101,
    parameter PROD_W  = 36,
    parameter ACC_W   = 64
) (
    input  [PROD_W*TAP_CNT-1:0] products_flat,
    output signed [ACC_W-1:0]   acc
);

    reg signed [ACC_W-1:0] acc_sum;
    reg signed [PROD_W-1:0] prod_i;
    integer i;

    always @* begin
        acc_sum = {ACC_W{1'b0}};

        for (i = 0; i < TAP_CNT; i = i + 1) begin
            prod_i  = products_flat[i*PROD_W +: PROD_W];
            acc_sum = acc_sum + {{(ACC_W-PROD_W){prod_i[PROD_W-1]}}, prod_i};
        end
    end

    assign acc = acc_sum;

endmodule