`timescale 1ns/1ps

module dct8_coeff_pack #(
    parameter COEFF_W = 16
) (
    input mode,
    input [2:0] out_index,

    output reg signed [COEFF_W-1:0] c0,
    output reg signed [COEFF_W-1:0] c1,
    output reg signed [COEFF_W-1:0] c2,
    output reg signed [COEFF_W-1:0] c3,
    output reg signed [COEFF_W-1:0] c4,
    output reg signed [COEFF_W-1:0] c5,
    output reg signed [COEFF_W-1:0] c6,
    output reg signed [COEFF_W-1:0] c7
);

    always @* begin
        c0 = {COEFF_W{1'b0}};
        c1 = {COEFF_W{1'b0}};
        c2 = {COEFF_W{1'b0}};
        c3 = {COEFF_W{1'b0}};
        c4 = {COEFF_W{1'b0}};
        c5 = {COEFF_W{1'b0}};
        c6 = {COEFF_W{1'b0}};
        c7 = {COEFF_W{1'b0}};

        if (mode == 1'b0) begin
            case (out_index)
                3'd0: begin
                    c0 =  16'sd5793; c1 =  16'sd5793; c2 =  16'sd5793; c3 =  16'sd5793;
                    c4 =  16'sd5793; c5 =  16'sd5793; c6 =  16'sd5793; c7 =  16'sd5793;
                end

                3'd1: begin
                    c0 =  16'sd8035; c1 =  16'sd6811; c2 =  16'sd4551; c3 =  16'sd1598;
                    c4 = -16'sd1598; c5 = -16'sd4551; c6 = -16'sd6811; c7 = -16'sd8035;
                end

                3'd2: begin
                    c0 =  16'sd7568; c1 =  16'sd3135; c2 = -16'sd3135; c3 = -16'sd7568;
                    c4 = -16'sd7568; c5 = -16'sd3135; c6 =  16'sd3135; c7 =  16'sd7568;
                end

                3'd3: begin
                    c0 =  16'sd6811; c1 = -16'sd1598; c2 = -16'sd8035; c3 = -16'sd4551;
                    c4 =  16'sd4551; c5 =  16'sd8035; c6 =  16'sd1598; c7 = -16'sd6811;
                end

                3'd4: begin
                    c0 =  16'sd5793; c1 = -16'sd5793; c2 = -16'sd5793; c3 =  16'sd5793;
                    c4 =  16'sd5793; c5 = -16'sd5793; c6 = -16'sd5793; c7 =  16'sd5793;
                end

                3'd5: begin
                    c0 =  16'sd4551; c1 = -16'sd8035; c2 =  16'sd1598; c3 =  16'sd6811;
                    c4 = -16'sd6811; c5 = -16'sd1598; c6 =  16'sd8035; c7 = -16'sd4551;
                end

                3'd6: begin
                    c0 =  16'sd3135; c1 = -16'sd7568; c2 =  16'sd7568; c3 = -16'sd3135;
                    c4 = -16'sd3135; c5 =  16'sd7568; c6 = -16'sd7568; c7 =  16'sd3135;
                end

                3'd7: begin
                    c0 =  16'sd1598; c1 = -16'sd4551; c2 =  16'sd6811; c3 = -16'sd8035;
                    c4 =  16'sd8035; c5 = -16'sd6811; c6 =  16'sd4551; c7 = -16'sd1598;
                end

                default: begin
                    c0 = {COEFF_W{1'b0}};
                    c1 = {COEFF_W{1'b0}};
                    c2 = {COEFF_W{1'b0}};
                    c3 = {COEFF_W{1'b0}};
                    c4 = {COEFF_W{1'b0}};
                    c5 = {COEFF_W{1'b0}};
                    c6 = {COEFF_W{1'b0}};
                    c7 = {COEFF_W{1'b0}};
                end
            endcase
        end else begin
            case (out_index)
                3'd0: begin
                    c0 =  16'sd5793; c1 =  16'sd8035; c2 =  16'sd7568; c3 =  16'sd6811;
                    c4 =  16'sd5793; c5 =  16'sd4551; c6 =  16'sd3135; c7 =  16'sd1598;
                end

                3'd1: begin
                    c0 =  16'sd5793; c1 =  16'sd6811; c2 =  16'sd3135; c3 = -16'sd1598;
                    c4 = -16'sd5793; c5 = -16'sd8035; c6 = -16'sd7568; c7 = -16'sd4551;
                end

                3'd2: begin
                    c0 =  16'sd5793; c1 =  16'sd4551; c2 = -16'sd3135; c3 = -16'sd8035;
                    c4 = -16'sd5793; c5 =  16'sd1598; c6 =  16'sd7568; c7 =  16'sd6811;
                end

                3'd3: begin
                    c0 =  16'sd5793; c1 =  16'sd1598; c2 = -16'sd7568; c3 = -16'sd4551;
                    c4 =  16'sd5793; c5 =  16'sd6811; c6 = -16'sd3135; c7 = -16'sd8035;
                end

                3'd4: begin
                    c0 =  16'sd5793; c1 = -16'sd1598; c2 = -16'sd7568; c3 =  16'sd4551;
                    c4 =  16'sd5793; c5 = -16'sd6811; c6 = -16'sd3135; c7 =  16'sd8035;
                end

                3'd5: begin
                    c0 =  16'sd5793; c1 = -16'sd4551; c2 = -16'sd3135; c3 =  16'sd8035;
                    c4 = -16'sd5793; c5 = -16'sd1598; c6 =  16'sd7568; c7 = -16'sd6811;
                end

                3'd6: begin
                    c0 =  16'sd5793; c1 = -16'sd6811; c2 =  16'sd3135; c3 =  16'sd1598;
                    c4 = -16'sd5793; c5 =  16'sd8035; c6 = -16'sd7568; c7 =  16'sd4551;
                end

                3'd7: begin
                    c0 =  16'sd5793; c1 = -16'sd8035; c2 =  16'sd7568; c3 = -16'sd6811;
                    c4 =  16'sd5793; c5 = -16'sd4551; c6 =  16'sd3135; c7 = -16'sd1598;
                end

                default: begin
                    c0 = {COEFF_W{1'b0}};
                    c1 = {COEFF_W{1'b0}};
                    c2 = {COEFF_W{1'b0}};
                    c3 = {COEFF_W{1'b0}};
                    c4 = {COEFF_W{1'b0}};
                    c5 = {COEFF_W{1'b0}};
                    c6 = {COEFF_W{1'b0}};
                    c7 = {COEFF_W{1'b0}};
                end
            endcase
        end
    end

endmodule