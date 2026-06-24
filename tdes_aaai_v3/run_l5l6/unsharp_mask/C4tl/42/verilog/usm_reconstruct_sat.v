`timescale 1ns/1ps

module usm_reconstruct_sat #(
    parameter PIXEL_W = 8,
    parameter GAIN_W  = 8
) (
    input  [PIXEL_W-1:0] orig,
    input  signed [PIXEL_W+GAIN_W+1:0] scaled,
    output reg [PIXEL_W-1:0] pixel_out
);

    localparam SCALE_W = PIXEL_W + GAIN_W + 2;
    localparam SUM_W   = SCALE_W + 1;

    wire signed [SUM_W-1:0] orig_ext;
    wire signed [SUM_W-1:0] scaled_ext;
    wire signed [SUM_W-1:0] sum;
    wire signed [SUM_W-1:0] max_pixel;

    assign orig_ext   = $signed({{(SUM_W-PIXEL_W){1'b0}}, orig});
    assign scaled_ext = $signed({scaled[SCALE_W-1], scaled});
    assign sum        = orig_ext + scaled_ext;

    assign max_pixel  = $signed({{(SUM_W-PIXEL_W){1'b0}}, {PIXEL_W{1'b1}}});

    always @* begin
        if (sum < 0) begin
            pixel_out = {PIXEL_W{1'b0}};
        end else if (sum > max_pixel) begin
            pixel_out = {PIXEL_W{1'b1}};
        end else begin
            pixel_out = sum[PIXEL_W-1:0];
        end
    end

endmodule