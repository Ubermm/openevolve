module bit_rev #(
    parameter W = 4
) (
    input  wire [W-1:0] in,
    output wire [W-1:0] out
);
    genvar i;
    generate
        for (i = 0; i < W; i = i + 1) begin : gen_rev
            assign out[i] = in[W-1-i];
        end
    endgenerate
endmodule