module bit_reverse #(
    parameter WIDTH = 4
) (
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    genvar i;
    // Combinational bit-reversal: out[i] = in[WIDTH-1-i]
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_rev
            assign out[i] = in[WIDTH-1-i];
        end
    endgenerate
endmodule