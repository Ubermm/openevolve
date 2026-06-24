`timescale 1ns/1ps

module dct8_coeff_rom #(
    parameter COEFF_W = 16
) (
    input  mode,
    input  [2:0] out_index,
    input  [2:0] in_index,
    output signed [COEFF_W-1:0] coeff
);

    /*
     * Stored table is the forward orthonormal DCT matrix C[k][n].
     *
     * DCT  mode: coefficient for output k and input n is C[k][n]
     *            row = out_index, col = in_index
     *
     * IDCT mode: inverse of orthonormal DCT is transpose(C).
     *            coefficient for output n and input k is C[k][n]
     *            row = in_index, col = out_index
     */
    wire [2:0] row;
    wire [2:0] col;

    assign row = mode ? in_index  : out_index;
    assign col = mode ? out_index : in_index;

    function signed [COEFF_W-1:0] coeff_value;
        input [2:0] r;
        input [2:0] c;
        begin
            case (r)
                3'd0: begin
                    coeff_value = 16'sd5793;
                end

                3'd1: begin
                    case (c)
                        3'd0: coeff_value =  16'sd8035;
                        3'd1: coeff_value =  16'sd6811;
                        3'd2: coeff_value =  16'sd4552;
                        3'd3: coeff_value =  16'sd1598;
                        3'd4: coeff_value = -16'sd1598;
                        3'd5: coeff_value = -16'sd4552;
                        3'd6: coeff_value = -16'sd6811;
                        3'd7: coeff_value = -16'sd8035;
                        default: coeff_value = {COEFF_W{1'b0}};
                    endcase
                end

                3'd2: begin
                    case (c)
                        3'd0: coeff_value =  16'sd7568;
                        3'd1: coeff_value =  16'sd3135;
                        3'd2: coeff_value = -16'sd3135;
                        3'd3: coeff_value = -16'sd7568;
                        3'd4: coeff_value = -16'sd7568;
                        3'd5: coeff_value = -16'sd3135;
                        3'd6: coeff_value =  16'sd3135;
                        3'd7: coeff_value =  16'sd7568;
                        default: coeff_value = {COEFF_W{1'b0}};
                    endcase
                end

                3'd3: begin
                    case (c)
                        3'd0: coeff_value =  16'sd6811;
                        3'd1: coeff_value = -16'sd1598;
                        3'd2: coeff_value = -16'sd8035;
                        3'd3: coeff_value = -16'sd4552;
                        3'd4: coeff_value =  16'sd4552;
                        3'd5: coeff_value =  16'sd8035;
                        3'd6: coeff_value =  16'sd1598;
                        3'd7: coeff_value = -16'sd6811;
                        default: coeff_value = {COEFF_W{1'b0}};
                    endcase
                end

                3'd4: begin
                    case (c)
                        3'd0: coeff_value =  16'sd5793;
                        3'd1: coeff_value = -16'sd5793;
                        3'd2: coeff_value = -16'sd5793;
                        3'd3: coeff_value =  16'sd5793;
                        3'd4: coeff_value =  16'sd5793;
                        3'd5: coeff_value = -16'sd5793;
                        3'd6: coeff_value = -16'sd5793;
                        3'd7: coeff_value =  16'sd5793;
                        default: coeff_value = {COEFF_W{1'b0}};
                    endcase
                end

                3'd5: begin
                    case (c)
                        3'd0: coeff_value =  16'sd4552;
                        3'd1: coeff_value = -16'sd8035;
                        3'd2: coeff_value =  16'sd1598;
                        3'd3: coeff_value =  16'sd6811;
                        3'd4: coeff_value = -16'sd6811;
                        3'd5: coeff_value = -16'sd1598;
                        3'd6: coeff_value =  16'sd8035;
                        3'd7: coeff_value = -16'sd4552;
                        default: coeff_value = {COEFF_W{1'b0}};
                    endcase
                end

                3'd6: begin
                    case (c)
                        3'd0: coeff_value =  16'sd3135;
                        3'd1: coeff_value = -16'sd7568;
                        3'd2: coeff_value =  16'sd7568;
                        3'd3: coeff_value = -16'sd3135;
                        3'd4: coeff_value = -16'sd3135;
                        3'd5: coeff_value =  16'sd7568;
                        3'd6: coeff_value = -16'sd7568;
                        3'd7: coeff_value =  16'sd3135;
                        default: coeff_value = {COEFF_W{1'b0}};
                    endcase
                end

                3'd7: begin
                    case (c)
                        3'd0: coeff_value =  16'sd1598;
                        3'd1: coeff_value = -16'sd4552;
                        3'd2: coeff_value =  16'sd6811;
                        3'd3: coeff_value = -16'sd8035;
                        3'd4: coeff_value =  16'sd8035;
                        3'd5: coeff_value = -16'sd6811;
                        3'd6: coeff_value =  16'sd4552;
                        3'd7: coeff_value = -16'sd1598;
                        default: coeff_value = {COEFF_W{1'b0}};
                    endcase
                end

                default: begin
                    coeff_value = {COEFF_W{1'b0}};
                end
            endcase
        end
    endfunction

    assign coeff = coeff_value(row, col);

endmodule