`timescale 1ns/1ps

module fft_complex_addsub #(
    parameter W = 20
) (
    input  signed [W-1:0] a_real,
    input  signed [W-1:0] a_imag,
    input  signed [W-1:0] b_real,
    input  signed [W-1:0] b_imag,
    output signed [W-1:0] sum_real,
    output signed [W-1:0] sum_imag,
    output signed [W-1:0] diff_real,
    output signed [W-1:0] diff_imag
);

    localparam signed [W-1:0] SAT_MAX = {1'b0, {(W-1){1'b1}}};
    localparam signed [W-1:0] SAT_MIN = {1'b1, {(W-1){1'b0}}};

    localparam signed [W:0] SAT_MAX_EXT = {1'b0, SAT_MAX};
    localparam signed [W:0] SAT_MIN_EXT = {1'b1, SAT_MIN};

    wire signed [W:0] a_real_ext = {a_real[W-1], a_real};
    wire signed [W:0] a_imag_ext = {a_imag[W-1], a_imag};
    wire signed [W:0] b_real_ext = {b_real[W-1], b_real};
    wire signed [W:0] b_imag_ext = {b_imag[W-1], b_imag};

    wire signed [W:0] sum_real_ext  = a_real_ext + b_real_ext;
    wire signed [W:0] sum_imag_ext  = a_imag_ext + b_imag_ext;
    wire signed [W:0] diff_real_ext = a_real_ext - b_real_ext;
    wire signed [W:0] diff_imag_ext = a_imag_ext - b_imag_ext;

    function signed [W-1:0] sat_to_w;
        input signed [W:0] value;
        begin
            if (value > SAT_MAX_EXT)
                sat_to_w = SAT_MAX;
            else if (value < SAT_MIN_EXT)
                sat_to_w = SAT_MIN;
            else
                sat_to_w = value[W-1:0];
        end
    endfunction

    assign sum_real  = sat_to_w(sum_real_ext);
    assign sum_imag  = sat_to_w(sum_imag_ext);
    assign diff_real = sat_to_w(diff_real_ext);
    assign diff_imag = sat_to_w(diff_imag_ext);

endmodule