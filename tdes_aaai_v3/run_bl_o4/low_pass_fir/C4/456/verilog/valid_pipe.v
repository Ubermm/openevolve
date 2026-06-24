module valid_pipe #(
  parameter integer TAP_CNT = 1
)(
  input  wire clk,
  input  wire rst,       // synchronous active-high reset
  input  wire valid_in,
  output wire valid_out
);

generate
  if (TAP_CNT > 0) begin : GEN_VALID_PIPE
    // Pipeline the valid signal for TAP_CNT cycles with synchronous reset
    reg [TAP_CNT-1:0] vpipe;
    always @(posedge clk) begin
      if (rst)
        vpipe <= {TAP_CNT{1'b0}};
      else
        vpipe <= {vpipe[TAP_CNT-2:0], valid_in};
    end
    assign valid_out = vpipe[TAP_CNT-1];
  end else begin : GEN_BYPASS
    // No stages: pass through, but clear during reset
    assign valid_out = rst ? 1'b0 : valid_in;
  end
endgenerate

endmodule