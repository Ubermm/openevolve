`timescale 1ns/1ps

module sqrt_nr_average_update #(
    parameter N = 16
)(
    input  [N-1:0] current_y,
    input  [N-1:0] div_term,
    output [N-1:0] next_y
);

    wire [N:0] sum_ext;

    assign sum_ext = {1'b0, current_y} + {1'b0, div_term};
    assign next_y  = sum_ext[N:1];

endmodule