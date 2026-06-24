`timescale 1ns/1ps

module conv1d_coeff_bank #(
    parameter KERNEL_SIZE = 5,
    parameter COEFF_W     = 12
) (
    output [KERNEL_SIZE*COEFF_W-1:0] coeffs_flat
);

    function signed [COEFF_W-1:0] default_coeff;
        input integer idx;
        begin
            default_coeff = {COEFF_W{1'b0}};

            case (KERNEL_SIZE)
                3: begin
                    case (idx)
                        0: default_coeff = 1;
                        1: default_coeff = 2;
                        2: default_coeff = 1;
                        default: default_coeff = 0;
                    endcase
                end

                5: begin
                    case (idx)
                        0: default_coeff = 2;
                        1: default_coeff = 8;
                        2: default_coeff = 12;
                        3: default_coeff = 8;
                        4: default_coeff = 2;
                        default: default_coeff = 0;
                    endcase
                end

                7: begin
                    case (idx)
                        0: default_coeff = 1;
                        1: default_coeff = 6;
                        2: default_coeff = 15;
                        3: default_coeff = 20;
                        4: default_coeff = 15;
                        5: default_coeff = 6;
                        6: default_coeff = 1;
                        default: default_coeff = 0;
                    endcase
                end

                default: begin
                    if (idx == (KERNEL_SIZE / 2))
                        default_coeff = 1;
                    else
                        default_coeff = 0;
                end
            endcase
        end
    endfunction

    genvar gi;
    generate
        for (gi = 0; gi < KERNEL_SIZE; gi = gi + 1) begin : gen_coeff_assign
            assign coeffs_flat[gi*COEFF_W +: COEFF_W] = default_coeff(gi);
        end
    endgenerate

endmodule