module fp_align (
    input        signA,
    input        signB,
    input  [7:0] expA,
    input  [7:0] expB,
    input  [23:0] fracA,
    input  [23:0] fracB,
    input        isZeroA,
    input        isZeroB,
    input        isInfA,
    input        isInfB,
    input        isNanA,
    input        isNanB,
    output       signA_o,
    output       signB_o,
    output [7:0] exp,
    output [26:0] manA,
    output [26:0] manB,
    output       isZeroA_o,
    output       isZeroB_o,
    output       isInfA_o,
    output       isInfB_o,
    output       isNanA_o,
    output       isNanB_o
);
    assign signA_o = 0;
    assign signB_o = 0;
    assign exp     = 0;
    assign manA    = 0;
    assign manB    = 0;
    assign isZeroA_o = 0;
    assign isZeroB_o = 0;
    assign isInfA_o  = 0;
    assign isInfB_o  = 0;
    assign isNanA_o  = 0;
    assign isNanB_o  = 0;
endmodule