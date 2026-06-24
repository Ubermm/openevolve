module fp_round_pack (
    input         sign,
    input  [7:0]  exp_in,
    input  [27:0] man_in,
    input         isZero,
    input         isInfA,
    input         isInfB,
    input         isNanA,
    input         isNanB,
    output [31:0] result
);
    assign result = 0;
endmodule