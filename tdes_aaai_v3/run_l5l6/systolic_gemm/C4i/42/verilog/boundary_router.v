`ifndef BOUNDARY_ROUTER_V
`define BOUNDARY_ROUTER_V

module boundary_router(a_west0, a_west1, a_west2, a_west3,
                       b_north0, b_north1, b_north2, b_north3,
                       a_boundary0, a_boundary1, a_boundary2, a_boundary3,
                       b_boundary0, b_boundary1, b_boundary2, b_boundary3);

    input  [31:0] a_west0,  a_west1,  a_west2,  a_west3;
    input  [31:0] b_north0, b_north1, b_north2, b_north3;

    output [31:0] a_boundary0, a_boundary1, a_boundary2, a_boundary3;
    output [31:0] b_boundary0, b_boundary1, b_boundary2, b_boundary3;

    assign a_boundary0 = a_west0;
    assign a_boundary1 = a_west1;
    assign a_boundary2 = a_west2;
    assign a_boundary3 = a_west3;

    assign b_boundary0 = b_north0;
    assign b_boundary1 = b_north1;
    assign b_boundary2 = b_north2;
    assign b_boundary3 = b_north3;

endmodule

`endif