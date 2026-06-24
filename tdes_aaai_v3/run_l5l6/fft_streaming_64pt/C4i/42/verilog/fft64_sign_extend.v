`timescale 1ns/1ps

module fft64_sign_extend #(
    parameter IN_W  = 16,
    parameter OUT_W = 20
) (
    input  signed [IN_W-1:0]  in_re,
    input  signed [IN_W-1:0]  in_im,
    output signed [OUT_W-1:0] out_re,
    output signed [OUT_W-1:0] out_im
);

generate
    if (OUT_W > IN_W) begin : gen_sign_extend
        assign out_re = {{(OUT_W-IN_W){in_re[IN_W-1]}}, in_re};
        assign out_im = {{(OUT_W-IN_W){in_im[IN_W-1]}}, in_im};
    end else begin : gen_no_extend
        assign out_re = in_re[OUT_W-1:0];
        assign out_im = in_im[OUT_W-1:0];
    end
endgenerate

endmodule