`timescale 1ns/1ps

module conv2d_coeff_rom #(
    parameter KERNEL_SIZE = 3,
    parameter COEFF_W     = 16
) (
    output reg [COEFF_W*KERNEL_SIZE*KERNEL_SIZE-1:0] coeffs
);

    integer i;
    integer center_row;
    integer center_col;
    integer center_idx;

    always @* begin
        // Default all coefficients to zero.
        coeffs = {COEFF_W*KERNEL_SIZE*KERNEL_SIZE{1'b0}};

        if (KERNEL_SIZE == 3) begin
            // Row-major flattened 3x3 Gaussian-style kernel:
            // [ 1 2 1
            //   2 4 2
            //   1 2 1 ]
            coeffs[0*COEFF_W +: COEFF_W] = 1;
            coeffs[1*COEFF_W +: COEFF_W] = 2;
            coeffs[2*COEFF_W +: COEFF_W] = 1;

            coeffs[3*COEFF_W +: COEFF_W] = 2;
            coeffs[4*COEFF_W +: COEFF_W] = 4;
            coeffs[5*COEFF_W +: COEFF_W] = 2;

            coeffs[6*COEFF_W +: COEFF_W] = 1;
            coeffs[7*COEFF_W +: COEFF_W] = 2;
            coeffs[8*COEFF_W +: COEFF_W] = 1;
        end else begin
            // Other supported kernel sizes default to identity:
            // all zeros except the center tap.
            center_row = KERNEL_SIZE / 2;
            center_col = KERNEL_SIZE / 2;
            center_idx = center_row*KERNEL_SIZE + center_col;

            coeffs[center_idx*COEFF_W +: COEFF_W] = 1;
        end
    end

endmodule