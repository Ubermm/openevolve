`timescale 1ns/1ps

module sqrt_nr_fixedpoint_divide #(
    parameter N = 16,
    parameter M = 8
)(
    input  [N-1:0] X,
    input  [N-1:0] y,
    output [N-1:0] quotient
);

    localparam EXT_WIDTH = N + M;

    wire [EXT_WIDTH-1:0] numerator;
    wire [EXT_WIDTH-1:0] quotient_full;
    wire                 overflow;

    generate
        if (M == 0) begin : gen_num_m0
            assign numerator = X;
        end else begin : gen_num_mgt0
            assign numerator = {X, {M{1'b0}}};
        end
    endgenerate

    assign quotient_full = (y == {N{1'b0}}) ? {EXT_WIDTH{1'b1}} :
                           (numerator / y);

    generate
        if (M == 0) begin : gen_ovf_m0
            assign overflow = 1'b0;
        end else begin : gen_ovf_mgt0
            assign overflow = |quotient_full[EXT_WIDTH-1:N];
        end
    endgenerate

    assign quotient = ((y == {N{1'b0}}) || overflow) ? {N{1'b1}} :
                       quotient_full[N-1:0];

endmodule