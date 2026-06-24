`include "pe.v"
`include "boundary_router.v"
`include "cycle_control_logic.v"
`include "result_bus_mapper.v"

module systolic_matrix_mult(a_west0, a_west1, a_west2, a_west3,
                           b_north0, b_north1, b_north2, b_north3,
                           clk, rst, done,
                           result0, result1, result2, result3,
                           result4, result5, result6, result7,
                           result8, result9, result10, result11,
                           result12, result13, result14, result15);

    input [31:0] a_west0, a_west1, a_west2, a_west3,
                 b_north0, b_north1, b_north2, b_north3;
    output reg done;
    input clk, rst;
    output [63:0] result0, result1, result2, result3,
                  result4, result5, result6, result7,
                  result8, result9, result10, result11,
                  result12, result13, result14, result15;

    wire [31:0] a_boundary0, a_boundary1, a_boundary2, a_boundary3;
    wire [31:0] b_boundary0, b_boundary1, b_boundary2, b_boundary3;

    boundary_router u_boundary_router (
        .a_west0(a_west0), .a_west1(a_west1), .a_west2(a_west2), .a_west3(a_west3),
        .b_north0(b_north0), .b_north1(b_north1), .b_north2(b_north2), .b_north3(b_north3),
        .a_boundary0(a_boundary0), .a_boundary1(a_boundary1),
        .a_boundary2(a_boundary2), .a_boundary3(a_boundary3),
        .b_boundary0(b_boundary0), .b_boundary1(b_boundary1),
        .b_boundary2(b_boundary2), .b_boundary3(b_boundary3)
    );

    reg [31:0] east_reg00, east_reg01, east_reg02, east_reg03;
    reg [31:0] east_reg10, east_reg11, east_reg12, east_reg13;
    reg [31:0] east_reg20, east_reg21, east_reg22, east_reg23;
    reg [31:0] east_reg30, east_reg31, east_reg32, east_reg33;

    reg [31:0] south_reg00, south_reg01, south_reg02, south_reg03;
    reg [31:0] south_reg10, south_reg11, south_reg12, south_reg13;
    reg [31:0] south_reg20, south_reg21, south_reg22, south_reg23;
    reg [31:0] south_reg30, south_reg31, south_reg32, south_reg33;

    wire [31:0] east_comb00, east_comb01, east_comb02, east_comb03;
    wire [31:0] east_comb10, east_comb11, east_comb12, east_comb13;
    wire [31:0] east_comb20, east_comb21, east_comb22, east_comb23;
    wire [31:0] east_comb30, east_comb31, east_comb32, east_comb33;

    wire [31:0] south_comb00, south_comb01, south_comb02, south_comb03;
    wire [31:0] south_comb10, south_comb11, south_comb12, south_comb13;
    wire [31:0] south_comb20, south_comb21, south_comb22, south_comb23;
    wire [31:0] south_comb30, south_comb31, south_comb32, south_comb33;

    wire [63:0] product00, product01, product02, product03;
    wire [63:0] product10, product11, product12, product13;
    wire [63:0] product20, product21, product22, product23;
    wire [63:0] product30, product31, product32, product33;

    reg [63:0] acc00, acc01, acc02, acc03;
    reg [63:0] acc10, acc11, acc12, acc13;
    reg [63:0] acc20, acc21, acc22, acc23;
    reg [63:0] acc30, acc31, acc32, acc33;

    reg [3:0] cycle_count;
    wire [3:0] next_cycle_count;
    wire done_next;

    cycle_control_logic u_cycle_control_logic (
        .cycle_count(cycle_count),
        .next_cycle_count(next_cycle_count),
        .done_next(done_next)
    );

    pe u_pe00 (.north_in(b_boundary0), .west_in(a_boundary0), .clk(clk), .rst(rst),
               .south_out(south_comb00), .east_out(east_comb00), .result(product00));
    pe u_pe01 (.north_in(b_boundary1), .west_in(east_reg00), .clk(clk), .rst(rst),
               .south_out(south_comb01), .east_out(east_comb01), .result(product01));
    pe u_pe02 (.north_in(b_boundary2), .west_in(east_reg01), .clk(clk), .rst(rst),
               .south_out(south_comb02), .east_out(east_comb02), .result(product02));
    pe u_pe03 (.north_in(b_boundary3), .west_in(east_reg02), .clk(clk), .rst(rst),
               .south_out(south_comb03), .east_out(east_comb03), .result(product03));

    pe u_pe10 (.north_in(south_reg00), .west_in(a_boundary1), .clk(clk), .rst(rst),
               .south_out(south_comb10), .east_out(east_comb10), .result(product10));
    pe u_pe11 (.north_in(south_reg01), .west_in(east_reg10), .clk(clk), .rst(rst),
               .south_out(south_comb11), .east_out(east_comb11), .result(product11));
    pe u_pe12 (.north_in(south_reg02), .west_in(east_reg11), .clk(clk), .rst(rst),
               .south_out(south_comb12), .east_out(east_comb12), .result(product12));
    pe u_pe13 (.north_in(south_reg03), .west_in(east_reg12), .clk(clk), .rst(rst),
               .south_out(south_comb13), .east_out(east_comb13), .result(product13));

    pe u_pe20 (.north_in(south_reg10), .west_in(a_boundary2), .clk(clk), .rst(rst),
               .south_out(south_comb20), .east_out(east_comb20), .result(product20));
    pe u_pe21 (.north_in(south_reg11), .west_in(east_reg20), .clk(clk), .rst(rst),
               .south_out(south_comb21), .east_out(east_comb21), .result(product21));
    pe u_pe22 (.north_in(south_reg12), .west_in(east_reg21), .clk(clk), .rst(rst),
               .south_out(south_comb22), .east_out(east_comb22), .result(product22));
    pe u_pe23 (.north_in(south_reg13), .west_in(east_reg22), .clk(clk), .rst(rst),
               .south_out(south_comb23), .east_out(east_comb23), .result(product23));

    pe u_pe30 (.north_in(south_reg20), .west_in(a_boundary3), .clk(clk), .rst(rst),
               .south_out(south_comb30), .east_out(east_comb30), .result(product30));
    pe u_pe31 (.north_in(south_reg21), .west_in(east_reg30), .clk(clk), .rst(rst),
               .south_out(south_comb31), .east_out(east_comb31), .result(product31));
    pe u_pe32 (.north_in(south_reg22), .west_in(east_reg31), .clk(clk), .rst(rst),
               .south_out(south_comb32), .east_out(east_comb32), .result(product32));
    pe u_pe33 (.north_in(south_reg23), .west_in(east_reg32), .clk(clk), .rst(rst),
               .south_out(south_comb33), .east_out(east_comb33), .result(product33));

    result_bus_mapper u_result_bus_mapper (
        .c00(acc00), .c01(acc01), .c02(acc02), .c03(acc03),
        .c10(acc10), .c11(acc11), .c12(acc12), .c13(acc13),
        .c20(acc20), .c21(acc21), .c22(acc22), .c23(acc23),
        .c30(acc30), .c31(acc31), .c32(acc32), .c33(acc33),
        .result0(result0), .result1(result1), .result2(result2), .result3(result3),
        .result4(result4), .result5(result5), .result6(result6), .result7(result7),
        .result8(result8), .result9(result9), .result10(result10), .result11(result11),
        .result12(result12), .result13(result13), .result14(result14), .result15(result15)
    );

    initial begin
        done = 1'b0;
        cycle_count = 4'd0;

        east_reg00 = 32'd0; east_reg01 = 32'd0; east_reg02 = 32'd0; east_reg03 = 32'd0;
        east_reg10 = 32'd0; east_reg11 = 32'd0; east_reg12 = 32'd0; east_reg13 = 32'd0;
        east_reg20 = 32'd0; east_reg21 = 32'd0; east_reg22 = 32'd0; east_reg23 = 32'd0;
        east_reg30 = 32'd0; east_reg31 = 32'd0; east_reg32 = 32'd0; east_reg33 = 32'd0;

        south_reg00 = 32'd0; south_reg01 = 32'd0; south_reg02 = 32'd0; south_reg03 = 32'd0;
        south_reg10 = 32'd0; south_reg11 = 32'd0; south_reg12 = 32'd0; south_reg13 = 32'd0;
        south_reg20 = 32'd0; south_reg21 = 32'd0; south_reg22 = 32'd0; south_reg23 = 32'd0;
        south_reg30 = 32'd0; south_reg31 = 32'd0; south_reg32 = 32'd0; south_reg33 = 32'd0;

        acc00 = 64'd0; acc01 = 64'd0; acc02 = 64'd0; acc03 = 64'd0;
        acc10 = 64'd0; acc11 = 64'd0; acc12 = 64'd0; acc13 = 64'd0;
        acc20 = 64'd0; acc21 = 64'd0; acc22 = 64'd0; acc23 = 64'd0;
        acc30 = 64'd0; acc31 = 64'd0; acc32 = 64'd0; acc33 = 64'd0;
    end

    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            cycle_count <= 4'd0;

            east_reg00 <= 32'd0; east_reg01 <= 32'd0; east_reg02 <= 32'd0; east_reg03 <= 32'd0;
            east_reg10 <= 32'd0; east_reg11 <= 32'd0; east_reg12 <= 32'd0; east_reg13 <= 32'd0;
            east_reg20 <= 32'd0; east_reg21 <= 32'd0; east_reg22 <= 32'd0; east_reg23 <= 32'd0;
            east_reg30 <= 32'd0; east_reg31 <= 32'd0; east_reg32 <= 32'd0; east_reg33 <= 32'd0;

            south_reg00 <= 32'd0; south_reg01 <= 32'd0; south_reg02 <= 32'd0; south_reg03 <= 32'd0;
            south_reg10 <= 32'd0; south_reg11 <= 32'd0; south_reg12 <= 32'd0; south_reg13 <= 32'd0;
            south_reg20 <= 32'd0; south_reg21 <= 32'd0; south_reg22 <= 32'd0; south_reg23 <= 32'd0;
            south_reg30 <= 32'd0; south_reg31 <= 32'd0; south_reg32 <= 32'd0; south_reg33 <= 32'd0;

            acc00 <= 64'd0; acc01 <= 64'd0; acc02 <= 64'd0; acc03 <= 64'd0;
            acc10 <= 64'd0; acc11 <= 64'd0; acc12 <= 64'd0; acc13 <= 64'd0;
            acc20 <= 64'd0; acc21 <= 64'd0; acc22 <= 64'd0; acc23 <= 64'd0;
            acc30 <= 64'd0; acc31 <= 64'd0; acc32 <= 64'd0; acc33 <= 64'd0;
        end else begin
            cycle_count <= next_cycle_count;
            done <= done_next;

            east_reg00 <= east_comb00; east_reg01 <= east_comb01; east_reg02 <= east_comb02; east_reg03 <= east_comb03;
            east_reg10 <= east_comb10; east_reg11 <= east_comb11; east_reg12 <= east_comb12; east_reg13 <= east_comb13;
            east_reg20 <= east_comb20; east_reg21 <= east_comb21; east_reg22 <= east_comb22; east_reg23 <= east_comb23;
            east_reg30 <= east_comb30; east_reg31 <= east_comb31; east_reg32 <= east_comb32; east_reg33 <= east_comb33;

            south_reg00 <= south_comb00; south_reg01 <= south_comb01; south_reg02 <= south_comb02; south_reg03 <= south_comb03;
            south_reg10 <= south_comb10; south_reg11 <= south_comb11; south_reg12 <= south_comb12; south_reg13 <= south_comb13;
            south_reg20 <= south_comb20; south_reg21 <= south_comb21; south_reg22 <= south_comb22; south_reg23 <= south_comb23;
            south_reg30 <= south_comb30; south_reg31 <= south_comb31; south_reg32 <= south_comb32; south_reg33 <= south_comb33;

            acc00 <= acc00 + product00; acc01 <= acc01 + product01; acc02 <= acc02 + product02; acc03 <= acc03 + product03;
            acc10 <= acc10 + product10; acc11 <= acc11 + product11; acc12 <= acc12 + product12; acc13 <= acc13 + product13;
            acc20 <= acc20 + product20; acc21 <= acc21 + product21; acc22 <= acc22 + product22; acc23 <= acc23 + product23;
            acc30 <= acc30 + product30; acc31 <= acc31 + product31; acc32 <= acc32 + product32; acc33 <= acc33 + product33;
        end
    end

endmodule