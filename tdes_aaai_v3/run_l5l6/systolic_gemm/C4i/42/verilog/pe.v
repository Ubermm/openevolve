`ifndef PE_V
`define PE_V

module pe(north_in, west_in, clk, rst, south_out, east_out, result);
    input [31:0] north_in, west_in;
    input clk, rst;

    output reg [31:0] south_out, east_out;
    output reg [63:0] result;

    wire signed [63:0] north_signed_ext;
    wire signed [63:0] west_signed_ext;

    assign north_signed_ext = {{32{north_in[31]}}, north_in};
    assign west_signed_ext  = {{32{west_in[31]}},  west_in};

    always @* begin
        south_out = north_in;
        east_out  = west_in;
        result    = north_signed_ext * west_signed_ext;
    end

endmodule

`endif