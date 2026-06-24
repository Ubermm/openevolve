module gs_reciprocal #(
    parameter DATA_WIDTH = 32,
    parameter FRAC = 16
)(
    input  [DATA_WIDTH-1:0] a,
    output reg [DATA_WIDTH-1:0] reciprocal
);

    localparam integer NUM_WIDTH = ((2*FRAC + 1) > (2*DATA_WIDTH)) ? (2*FRAC + 1) : (2*DATA_WIDTH);

    reg [NUM_WIDTH-1:0] numerator;
    reg [DATA_WIDTH-1:0] a_abs;
    reg [NUM_WIDTH-1:0] quotient_abs;
    reg sign;

    always @* begin
        numerator = {{(NUM_WIDTH-1){1'b0}}, 1'b1} << (2*FRAC);

        if (a == {DATA_WIDTH{1'b0}}) begin
            reciprocal = {DATA_WIDTH{1'b0}};
        end else begin
            sign = a[DATA_WIDTH-1];

            if (sign) begin
                a_abs = (~a) + {{(DATA_WIDTH-1){1'b0}}, 1'b1};
            end else begin
                a_abs = a;
            end

            quotient_abs = numerator / a_abs;

            if (sign) begin
                reciprocal = (~quotient_abs[DATA_WIDTH-1:0]) + {{(DATA_WIDTH-1){1'b0}}, 1'b1};
            end else begin
                reciprocal = quotient_abs[DATA_WIDTH-1:0];
            end
        end
    end

endmodule