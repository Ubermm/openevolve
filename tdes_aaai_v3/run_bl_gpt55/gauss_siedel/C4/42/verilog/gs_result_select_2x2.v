module gs_result_select_2x2 #(
    parameter DATA_WIDTH = 32,
    parameter FRAC = 16
)(
    input [DATA_WIDTH-1:0] a11,
    input [DATA_WIDTH-1:0] a12,
    input [DATA_WIDTH-1:0] a21,
    input [DATA_WIDTH-1:0] a22,
    input [DATA_WIDTH-1:0] b1,
    input [DATA_WIDTH-1:0] b2,
    input [DATA_WIDTH-1:0] direct_x1,
    input [DATA_WIDTH-1:0] direct_x2,
    input [DATA_WIDTH-1:0] iter_x1,
    input [DATA_WIDTH-1:0] iter_x2,
    output reg [DATA_WIDTH-1:0] x1_selected,
    output reg [DATA_WIDTH-1:0] x2_selected
);

    wire signed [DATA_WIDTH-1:0] a11_s = a11;
    wire signed [DATA_WIDTH-1:0] a12_s = a12;
    wire signed [DATA_WIDTH-1:0] a21_s = a21;
    wire signed [DATA_WIDTH-1:0] a22_s = a22;

    wire signed [(2*DATA_WIDTH)-1:0] det =
        (a11_s * a22_s) - (a12_s * a21_s);

    always @* begin
        if (det == {((2*DATA_WIDTH)){1'b0}}) begin
            x1_selected = iter_x1;
            x2_selected = iter_x2;
        end else begin
            x1_selected = direct_x1;
            x2_selected = direct_x2;
        end
    end

endmodule