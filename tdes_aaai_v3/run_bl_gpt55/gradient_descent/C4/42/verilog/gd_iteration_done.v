`default_nettype none

module gd_iteration_done #(
    parameter integer MAX_ITER  = 10,
    parameter integer CNT_WIDTH = 4
)(
    input  wire [CNT_WIDTH-1:0] iter_count,
    output wire                 last_iteration
);

    generate
        if (MAX_ITER <= 1) begin : gen_last_always
            assign last_iteration = 1'b1;
        end else begin : gen_last_compare
            assign last_iteration = (iter_count == (MAX_ITER - 1));
        end
    endgenerate

endmodule

`default_nettype wire