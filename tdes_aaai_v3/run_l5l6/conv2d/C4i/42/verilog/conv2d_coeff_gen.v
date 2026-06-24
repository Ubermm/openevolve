`timescale 1ns/1ps

module conv2d_coeff_gen #(
    parameter KERNEL_SIZE = 3,
    parameter COEFF_W    = 16
) (
    output reg [KERNEL_SIZE*KERNEL_SIZE*COEFF_W-1:0] coeffs_flat
);

    /*
     * Return binomial coefficients for the supported Gaussian-style kernels.
     *
     * KERNEL_SIZE = 3 -> n = 2 -> [1 2 1]
     * KERNEL_SIZE = 5 -> n = 4 -> [1 4 6 4 1]
     * KERNEL_SIZE = 7 -> n = 6 -> [1 6 15 20 15 6 1]
     */
    function integer binom_coeff;
        input integer n;
        input integer k;
        begin
            binom_coeff = 0;

            case (n)
                2: begin
                    case (k)
                        0: binom_coeff = 1;
                        1: binom_coeff = 2;
                        2: binom_coeff = 1;
                        default: binom_coeff = 0;
                    endcase
                end

                4: begin
                    case (k)
                        0: binom_coeff = 1;
                        1: binom_coeff = 4;
                        2: binom_coeff = 6;
                        3: binom_coeff = 4;
                        4: binom_coeff = 1;
                        default: binom_coeff = 0;
                    endcase
                end

                6: begin
                    case (k)
                        0: binom_coeff = 1;
                        1: binom_coeff = 6;
                        2: binom_coeff = 15;
                        3: binom_coeff = 20;
                        4: binom_coeff = 15;
                        5: binom_coeff = 6;
                        6: binom_coeff = 1;
                        default: binom_coeff = 0;
                    endcase
                end

                default: begin
                    binom_coeff = 0;
                end
            endcase
        end
    endfunction

    integer i;
    integer r;
    integer c;
    integer coeff_int;
    reg signed [COEFF_W-1:0] coeff_val;

    always @* begin
        coeffs_flat = {KERNEL_SIZE*KERNEL_SIZE*COEFF_W{1'b0}};

        for (i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
            r = i / KERNEL_SIZE;
            c = i % KERNEL_SIZE;

            if ((KERNEL_SIZE == 3) ||
                (KERNEL_SIZE == 5) ||
                (KERNEL_SIZE == 7)) begin

                coeff_int = binom_coeff(KERNEL_SIZE-1, r) *
                            binom_coeff(KERNEL_SIZE-1, c);

            end else begin
                /*
                 * Fallback for unsupported sizes: impulse kernel.
                 * This preserves the center pixel in the dot product.
                 */
                if ((r == (KERNEL_SIZE/2)) && (c == (KERNEL_SIZE/2))) begin
                    coeff_int = 1;
                end else begin
                    coeff_int = 0;
                end
            end

            coeff_val = coeff_int;
            coeffs_flat[i*COEFF_W +: COEFF_W] = coeff_val;
        end
    end

endmodule