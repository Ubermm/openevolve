module lowpass_fir_symmetric_preadd #(
    parameter DATA_W = 20
) (
    input  signed [DATA_W-1:0] sample_a,
    input  signed [DATA_W-1:0] sample_b,
    output signed [DATA_W:0]   sum_out
);

    assign sum_out =
        $signed({sample_a[DATA_W-1], sample_a}) +
        $signed({sample_b[DATA_W-1], sample_b});

endmodule