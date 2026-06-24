module output_shifter #(
    parameter integer IN_W   = 64,
    parameter integer OUT_W  = 24,
    parameter integer SHIFT  = 20
) (
    input  wire                      clk,
    input  wire                      rst,
    input  wire                      valid_in,
    input  wire signed [IN_W-1:0]    in,
    output reg                       valid_out,
    output reg signed [OUT_W-1:0]    out
);
    // Pipeline stage: latch valid, perform arithmetic right-shift
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            out       <= {OUT_W{1'b0}};
        end else begin
            valid_out <= valid_in;
            // Arithmetic right shift: take bits [SHIFT+OUT_W-1:SHIFT] of signed input
            out       <= in[SHIFT+OUT_W-1 : SHIFT];
        end
    end
endmodule