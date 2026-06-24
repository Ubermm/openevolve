`timescale 1ns/1ps

module fft64_output_clip #(
    parameter IN_W  = 20,
    parameter OUT_W = 20
) (
    input  signed [IN_W-1:0]  in_re,
    input  signed [IN_W-1:0]  in_im,
    output signed [OUT_W-1:0] out_re,
    output signed [OUT_W-1:0] out_im
);

    generate
        if (IN_W == OUT_W) begin : g_passthrough

            assign out_re = in_re;
            assign out_im = in_im;

        end else if (IN_W < OUT_W) begin : g_extend

            assign out_re = {{(OUT_W-IN_W){in_re[IN_W-1]}}, in_re};
            assign out_im = {{(OUT_W-IN_W){in_im[IN_W-1]}}, in_im};

        end else begin : g_clip

            wire re_fits;
            wire im_fits;

            assign re_fits =
                (in_re[IN_W-1:OUT_W-1] == {(IN_W-OUT_W+1){in_re[OUT_W-1]}});

            assign im_fits =
                (in_im[IN_W-1:OUT_W-1] == {(IN_W-OUT_W+1){in_im[OUT_W-1]}});

            assign out_re = re_fits                 ? in_re[OUT_W-1:0] :
                            (in_re[IN_W-1] == 1'b0) ? {1'b0, {(OUT_W-1){1'b1}}} :
                                                       {1'b1, {(OUT_W-1){1'b0}}};

            assign out_im = im_fits                 ? in_im[OUT_W-1:0] :
                            (in_im[IN_W-1] == 1'b0) ? {1'b0, {(OUT_W-1){1'b1}}} :
                                                       {1'b1, {(OUT_W-1){1'b0}}};

        end
    endgenerate

endmodule