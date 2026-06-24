`timescale 1ns/1ps

module conv2d_output_cast #(
    parameter ACC_W = 32,
    parameter OUT_W = 12
) (
    input  signed [ACC_W-1:0] sum_in,
    output reg    [OUT_W-1:0] pixel_out
);

    localparam [OUT_W-1:0] MAX_OUT = {OUT_W{1'b1}};

    generate
        if (ACC_W > OUT_W) begin : gen_acc_wider
            wire overflow;

            /*
             * For a non-negative signed accumulator, any set bit above the
             * output field means the value is larger than OUT_W can represent.
             * Negative values are handled first, so including the sign bit in
             * this reduction is safe.
             */
            assign overflow = |sum_in[ACC_W-1:OUT_W];

            always @* begin
                if (sum_in[ACC_W-1]) begin
                    pixel_out = {OUT_W{1'b0}};
                end else if (overflow) begin
                    pixel_out = MAX_OUT;
                end else begin
                    pixel_out = sum_in[OUT_W-1:0];
                end
            end
        end else if (ACC_W == OUT_W) begin : gen_same_width
            /*
             * No positive overflow is possible here because sum_in is signed.
             * Values with the MSB set are negative and clamp to zero.
             */
            always @* begin
                if (sum_in[ACC_W-1]) begin
                    pixel_out = {OUT_W{1'b0}};
                end else begin
                    pixel_out = sum_in[OUT_W-1:0];
                end
            end
        end else begin : gen_out_wider
            /*
             * Output is wider than the signed accumulator.  Non-negative values
             * are zero-extended; negative values clamp to zero.
             */
            always @* begin
                if (sum_in[ACC_W-1]) begin
                    pixel_out = {OUT_W{1'b0}};
                end else begin
                    pixel_out = {{(OUT_W-ACC_W){1'b0}}, sum_in};
                end
            end
        end
    endgenerate

endmodule