`timescale 1ns/1ps

module conv1d_output_cast #(
    parameter ACC_W = 28,
    parameter OUT_W = 12
) (
    input  signed [ACC_W-1:0] acc_in,
    output [OUT_W-1:0]        data_out
);

    generate
        if (ACC_W > OUT_W) begin : gen_truncate
            /*
             * The MAC accumulator is wider than the final output by guard bits.
             * Cast back to OUT_W by discarding the least-significant guard bits,
             * preserving the signed magnitude/sign information in the upper bits.
             */
            assign data_out = acc_in[ACC_W-1 -: OUT_W];
        end else if (ACC_W == OUT_W) begin : gen_passthrough
            assign data_out = acc_in;
        end else begin : gen_sign_extend
            /*
             * Defensive parameter handling: if the accumulator is narrower than
             * the requested output, sign-extend the signed accumulator value.
             */
            assign data_out = {{(OUT_W-ACC_W){acc_in[ACC_W-1]}}, acc_in};
        end
    endgenerate

endmodule