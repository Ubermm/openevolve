`timescale 1ns/1ps

module bpf_output_quantizer #(
    parameter ACC_W = 64,
    parameter OUT_W = 24,
    parameter SHIFT = 15
) (
    input  signed [ACC_W-1:0]  acc,
    output signed [OUT_W-1:0]  data_out
);

    wire signed [ACC_W-1:0] shifted_acc;

    assign shifted_acc = acc >>> SHIFT;

    generate
        if (OUT_W <= ACC_W) begin : gen_truncate
            assign data_out = shifted_acc[OUT_W-1:0];
        end else begin : gen_sign_extend
            assign data_out = {{(OUT_W-ACC_W){shifted_acc[ACC_W-1]}}, shifted_acc};
        end
    endgenerate

endmodule