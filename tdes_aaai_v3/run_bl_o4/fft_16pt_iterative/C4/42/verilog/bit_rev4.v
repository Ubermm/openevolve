module bit_rev4 #(
    parameter N      = 16,
    parameter DATA_W = 12
) (
    input  wire signed [DATA_W-1:0] in  [0:N-1],
    output wire signed [DATA_W-1:0] out [0:N-1]
);

    // Function to reverse 4-bit index
    function [3:0] rev4;
        input [3:0] x;
        begin
            rev4 = { x[0], x[1], x[2], x[3] };
        end
    endfunction

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : BITREV
            localparam [3:0] R_IDX = rev4(i[3:0]);
            // combinational bit‐reversal shuffle
            assign out[R_IDX] = in[i];
        end
    endgenerate

endmodule