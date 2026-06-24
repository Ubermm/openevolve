module fp_unpack (
    input            clk,
    input            rst,
    input      [31:0] a,
    input      [31:0] b,
    input            valid_in,
    output reg       signA,
    output reg       signB,
    output reg [7:0] expA,
    output reg [7:0] expB,
    output reg [23:0] fracA,
    output reg [23:0] fracB,
    output reg       isZeroA,
    output reg       isZeroB,
    output reg       isInfA,
    output reg       isInfB,
    output reg       isNanA,
    output reg       isNanB,
    output reg       valid_out
);

    // Intermediate raw fields
    wire [7:0]  expA_raw, expB_raw;
    wire [22:0] manA_raw, manB_raw;

    assign expA_raw = a[30:23];
    assign expB_raw = b[30:23];
    assign manA_raw = a[22:0];
    assign manB_raw = b[22:0];

    always @(posedge clk) begin
        if (rst) begin
            signA     <= 1'b0;
            signB     <= 1'b0;
            expA      <= 8'd0;
            expB      <= 8'd0;
            fracA     <= 24'd0;
            fracB     <= 24'd0;
            isZeroA   <= 1'b0;
            isZeroB   <= 1'b0;
            isInfA    <= 1'b0;
            isInfB    <= 1'b0;
            isNanA    <= 1'b0;
            isNanB    <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            // Pass through valid signal
            valid_out <= valid_in;

            // Sign extraction
            signA <= a[31];
            signB <= b[31];

            // Exponent fields
            expA  <= expA_raw;
            expB  <= expB_raw;

            // Zero detection: exp=0 and frac=0
            isZeroA <= (expA_raw == 8'd0) && (manA_raw == 23'd0);
            isZeroB <= (expB_raw == 8'd0) && (manB_raw == 23'd0);

            // Infinity detection: exp=all 1's and frac=0
            isInfA  <= (expA_raw == 8'hFF) && (manA_raw == 23'd0);
            isInfB  <= (expB_raw == 8'hFF) && (manB_raw == 23'd0);

            // NaN detection: exp=all 1's and frac!=0
            isNanA  <= (expA_raw == 8'hFF) && (manA_raw != 23'd0);
            isNanB  <= (expB_raw == 8'hFF) && (manB_raw != 23'd0);

            // Build normalized/significand with implicit leading one
            // For subnormals (exp=0), leading bit is zero
            fracA <= { (expA_raw == 8'd0 ? 1'b0 : 1'b1), manA_raw };
            fracB <= { (expB_raw == 8'd0 ? 1'b0 : 1'b1), manB_raw };
        end
    end

endmodule