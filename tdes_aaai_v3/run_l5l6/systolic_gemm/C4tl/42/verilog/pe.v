`timescale 1ns/1ps

module pe(north_in, west_in, clk, rst, south_out, east_out, result);
    input [31:0] north_in;
    input [31:0] west_in;
    input clk;
    input rst;

    output reg [31:0] south_out;
    output reg [31:0] east_out;
    output reg [63:0] result;

    wire signed [63:0] north_ext;
    wire signed [63:0] west_ext;
    wire signed [127:0] product_wide;
    wire signed [63:0] product_64;
    wire signed [63:0] accum_signed;
    wire signed [63:0] result_next;

    assign north_ext = {{32{north_in[31]}}, north_in};
    assign west_ext  = {{32{west_in[31]}},  west_in};

    assign product_wide = north_ext * west_ext;
    assign product_64   = product_wide[63:0];

    assign accum_signed = result;
    assign result_next  = accum_signed + product_64;

    /*
     * Match the oracle PE forwarding behavior: north/west values propagate
     * directly to south/east without an additional clock-cycle delay.
     */
    always @(*) begin
        south_out = north_in;
        east_out  = west_in;
    end

    /*
     * This PE interface has clk/rst instead of an explicit accum_in port, so
     * the accumulated result is held internally and updated synchronously.
     */
    always @(posedge clk) begin
        if (rst) begin
            result <= 64'b0;
        end else begin
            result <= result_next;
        end
    end

endmodule