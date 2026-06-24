module bit_reverse (
    input  wire        clk,   // clock input for pipeline register
    input  wire        rst,   // synchronous reset
    input  wire [3:0]  din,   // 4-bit input index
    output reg  [3:0]  dout   // 4-bit bit-reversed output, registered
);

    // Pipeline register for bit-reversal operation
    always @(posedge clk) begin
        if (rst) begin
            dout <= 4'b0000;
        end else begin
            // Reverse bits: dout[3]=din[0], dout[2]=din[1], dout[1]=din[2], dout[0]=din[3]
            dout <= { din[0], din[1], din[2], din[3] };
        end
    end

endmodule