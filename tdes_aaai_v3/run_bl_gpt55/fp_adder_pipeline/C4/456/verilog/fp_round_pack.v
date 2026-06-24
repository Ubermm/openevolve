module fp_round_pack (
    input         special_valid,
    input  [31:0] special_result,
    input         sign_in,
    input  [8:0]  exp_in,
    input  [27:0] sig_in,
    output reg [31:0] result
);
    assign result = 0;
endmodule
