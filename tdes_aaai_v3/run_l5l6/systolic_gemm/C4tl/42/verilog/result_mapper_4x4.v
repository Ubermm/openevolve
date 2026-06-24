`timescale 1ns/1ps

module result_mapper_4x4(acc00, acc01, acc02, acc03,
                         acc10, acc11, acc12, acc13,
                         acc20, acc21, acc22, acc23,
                         acc30, acc31, acc32, acc33,
                         result0, result1, result2, result3,
                         result4, result5, result6, result7,
                         result8, result9, result10, result11,
                         result12, result13, result14, result15);

    input [63:0] acc00, acc01, acc02, acc03;
    input [63:0] acc10, acc11, acc12, acc13;
    input [63:0] acc20, acc21, acc22, acc23;
    input [63:0] acc30, acc31, acc32, acc33;

    output [63:0] result0, result1, result2, result3;
    output [63:0] result4, result5, result6, result7;
    output [63:0] result8, result9, result10, result11;
    output [63:0] result12, result13, result14, result15;

    assign result0  = acc00;
    assign result1  = acc01;
    assign result2  = acc02;
    assign result3  = acc03;

    assign result4  = acc10;
    assign result5  = acc11;
    assign result6  = acc12;
    assign result7  = acc13;

    assign result8  = acc20;
    assign result9  = acc21;
    assign result10 = acc22;
    assign result11 = acc23;

    assign result12 = acc30;
    assign result13 = acc31;
    assign result14 = acc32;
    assign result15 = acc33;

endmodule