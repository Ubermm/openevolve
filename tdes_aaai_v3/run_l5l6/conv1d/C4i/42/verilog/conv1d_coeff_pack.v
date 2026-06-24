`timescale 1ns/1ps

module conv1d_coeff_pack #(
    parameter KERNEL_SIZE = 5,
    parameter COEFF_W     = 16
) (
    output reg [COEFF_W*KERNEL_SIZE-1:0] coeffs_flat
);

    integer i;

    function signed [COEFF_W-1:0] coeff_value;
        input integer idx;
        begin
            coeff_value = {COEFF_W{1'b0}};

            if (KERNEL_SIZE == 3) begin
                case (idx)
                    0: coeff_value = {{(COEFF_W-1){1'b0}}, 1'b1};
                    1: coeff_value = 2;
                    2: coeff_value = {{(COEFF_W-1){1'b0}}, 1'b1};
                    default: coeff_value = {COEFF_W{1'b0}};
                endcase
            end else if (KERNEL_SIZE == 5) begin
                case (idx)
                    0: coeff_value = 2;
                    1: coeff_value = 8;
                    2: coeff_value = 12;
                    3: coeff_value = 8;
                    4: coeff_value = 2;
                    default: coeff_value = {COEFF_W{1'b0}};
                endcase
            end else if (KERNEL_SIZE == 7) begin
                case (idx)
                    0: coeff_value = {{(COEFF_W-1){1'b0}}, 1'b1};
                    1: coeff_value = 6;
                    2: coeff_value = 15;
                    3: coeff_value = 20;
                    4: coeff_value = 15;
                    5: coeff_value = 6;
                    6: coeff_value = {{(COEFF_W-1){1'b0}}, 1'b1};
                    default: coeff_value = {COEFF_W{1'b0}};
                endcase
            end else begin
                if (idx == (KERNEL_SIZE / 2))
                    coeff_value = {{(COEFF_W-1){1'b0}}, 1'b1};
                else
                    coeff_value = {COEFF_W{1'b0}};
            end
        end
    endfunction

    always @* begin
        coeffs_flat = {(COEFF_W*KERNEL_SIZE){1'b0}};

        for (i = 0; i < KERNEL_SIZE; i = i + 1) begin
            coeffs_flat[i*COEFF_W +: COEFF_W] = coeff_value(i);
        end
    end

endmodule