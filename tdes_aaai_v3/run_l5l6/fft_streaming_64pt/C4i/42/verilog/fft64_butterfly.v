`timescale 1ns/1ps

module fft64_butterfly #(
    parameter W = 20
) (
    input  signed [W-1:0] x_re,
    input  signed [W-1:0] x_im,
    input  signed [W-1:0] y_re,
    input  signed [W-1:0] y_im,
    input                 sub,
    output signed [W-1:0] out_re,
    output signed [W-1:0] out_im
);

    wire signed [W:0] x_re_ext = {x_re[W-1], x_re};
    wire signed [W:0] x_im_ext = {x_im[W-1], x_im};
    wire signed [W:0] y_re_ext = {y_re[W-1], y_re};
    wire signed [W:0] y_im_ext = {y_im[W-1], y_im};

    wire signed [W:0] calc_re = sub ? (x_re_ext - y_re_ext)
                                    : (x_re_ext + y_re_ext);

    wire signed [W:0] calc_im = sub ? (x_im_ext - y_im_ext)
                                    : (x_im_ext + y_im_ext);

    assign out_re = calc_re[W-1:0];
    assign out_im = calc_im[W-1:0];

endmodule