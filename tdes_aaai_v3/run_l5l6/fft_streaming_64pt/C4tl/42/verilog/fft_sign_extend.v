`timescale 1ns/1ps

module fft_sign_extend #(
    parameter IN_W  = 16,
    parameter OUT_W = 20
) (
    input  signed [IN_W-1:0]  real_in,
    input  signed [IN_W-1:0]  imag_in,
    output signed [OUT_W-1:0] real_out,
    output signed [OUT_W-1:0] imag_out
);

generate
    if (OUT_W > IN_W) begin : gen_sign_extend
        assign real_out = {{(OUT_W-IN_W){real_in[IN_W-1]}}, real_in};
        assign imag_out = {{(OUT_W-IN_W){imag_in[IN_W-1]}}, imag_in};
    end else if (OUT_W == IN_W) begin : gen_passthrough
        assign real_out = real_in;
        assign imag_out = imag_in;
    end else begin : gen_truncate
        assign real_out = real_in[OUT_W-1:0];
        assign imag_out = imag_in[OUT_W-1:0];
    end
endgenerate

endmodule