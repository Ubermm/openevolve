`timescale 1ns/1ps

module harris_gaussian3x3 #(
    parameter IN_W = 32
) (
    input  signed [IN_W-1:0] v00,
    input  signed [IN_W-1:0] v01,
    input  signed [IN_W-1:0] v02,
    input  signed [IN_W-1:0] v10,
    input  signed [IN_W-1:0] v11,
    input  signed [IN_W-1:0] v12,
    input  signed [IN_W-1:0] v20,
    input  signed [IN_W-1:0] v21,
    input  signed [IN_W-1:0] v22,
    output reg signed [IN_W-1:0] out
);

    /*
     * Maximum weighted sum magnitude is 16 times the input magnitude.
     * IN_W + 4 bits is sufficient mathematically; one extra guard bit is
     * kept here to avoid any tool-dependent intermediate sizing surprises.
     */
    localparam SUM_W = IN_W + 5;

    reg signed [SUM_W-1:0] sum;

    function signed [SUM_W-1:0] sext;
        input signed [IN_W-1:0] x;
        begin
            sext = {{(SUM_W-IN_W){x[IN_W-1]}}, x};
        end
    endfunction

    always @* begin
        sum =   sext(v00)
              + (sext(v01) <<< 1)
              +  sext(v02)
              + (sext(v10) <<< 1)
              + (sext(v11) <<< 2)
              + (sext(v12) <<< 1)
              +  sext(v20)
              + (sext(v21) <<< 1)
              +  sext(v22);

        /*
         * Divide by 16 using arithmetic shift so signed IxIy smoothing
         * preserves the correct sign behavior.
         */
        out = sum >>> 4;
    end

endmodule