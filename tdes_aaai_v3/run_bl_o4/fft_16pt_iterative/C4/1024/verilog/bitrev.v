module bitrev #(
    parameter N      = 16,
    parameter LGN    = 4,
    parameter DATA_W = 16
) (
    input  signed [DATA_W-1:0] data_real_in [0:N-1],
    input  signed [DATA_W-1:0] data_imag_in [0:N-1],
    output signed [DATA_W-1:0] data_real_out[0:N-1],
    output signed [DATA_W-1:0] data_imag_out[0:N-1]
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : REV
            // compute bit-reversed index for LGN bits
            localparam [LGN-1:0] REV_IDX = {
                i[0],
                i[1],
                i[2],
                i[3]
            };
            assign data_real_out[i] = data_real_in[REV_IDX];
            assign data_imag_out[i] = data_imag_in[REV_IDX];
        end
    endgenerate
endmodule