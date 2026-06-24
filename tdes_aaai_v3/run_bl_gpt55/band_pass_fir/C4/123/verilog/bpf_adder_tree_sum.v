`timescale 1ns/1ps

module bpf_adder_tree_sum #(
    parameter TAP_CNT = 101,
    parameter PROD_W  = 64
) (
    input  [TAP_CNT*PROD_W-1:0] products_flat,
    output reg signed [PROD_W-1:0] sum
);

    integer i;
    reg signed [PROD_W-1:0] acc;

    always @* begin
        acc = {PROD_W{1'b0}};

        for (i = 0; i < TAP_CNT; i = i + 1) begin
            acc = acc + $signed(products_flat[i*PROD_W +: PROD_W]);
        end

        sum = acc;
    end

endmodule