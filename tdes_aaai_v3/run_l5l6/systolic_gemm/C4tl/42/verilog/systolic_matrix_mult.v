`timescale 1ns/1ps

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

    reg [3:0] cycle_count;
    wire [3:0] cycle_count_next;
    wire done_next;

    reg [31:0] east00, east01, east02, east03;
    reg [31:0] east10, east11, east12, east13;
    reg [31:0] east20, east21, east22, east23;
    reg [31:0] east30, east31, east32, east33;

    reg [31:0] south00, south01, south02, south03;
    reg [31:0] south10, south11, south12, south13;
    reg [31:0] south20, south21, south22, south23;
    reg [31:0] south30, south31, south32, south33;

    reg [63:0] acc00, acc01, acc02, acc03;
    reg [63:0] acc10, acc11, acc12, acc13;
    reg [63:0] acc20, acc21, acc22, acc23;
    reg [63:0] acc30, acc31, acc32, acc33;

    wire [31:0] east_next00, east_next01, east_next02, east_next03;
    wire [31:0] east_next10, east_next11, east_next12, east_next13;
    wire [31:0] east_next20, east_next21, east_next22, east_next23;
    wire [31:0] east_next30, east_next31, east_next32, east_next33;

    wire [31:0] south_next00, south_next01, south_next02, south_next03;
    wire [31:0] south_next10, south_next11, south_next12, south_next13;
    wire [31:0] south_next20, south_next21, south_next22, south_next23;
    wire [31:0] south_next30, south_next31, south_next32, south_next33;

    wire [63:0] acc_next00, acc_next01, acc_next02, acc_next03;
    wire [63:0] acc_next10, acc_next11, acc_next12, acc_next13;
    wire [63:0] acc_next20, acc_next21, acc_next22, acc_next23;
    wire [63:0] acc_next30, acc_next31, acc_next32, acc_next33;

    pe pe00(.north_in(b_north0), .west_in(a_west0), .accum_in(acc00),
            .south_out(south_next00), .east_out(east_next00), .result_next(acc_next00));
    pe pe01(.north_in(b_north1), .west_in(east00), .accum_in(acc01),
            .south_out(south_next01), .east_out(east_next01), .result_next(acc_next01));
    pe pe02(.north_in(b_north2), .west_in(east01), .accum_in(acc02),
            .south_out(south_next02), .east_out(east_next02), .result_next(acc_next02));
    pe pe03(.north_in(b_north3), .west_in(east02), .accum_in(acc03),
            .south_out(south_next03), .east_out(east_next03), .result_next(acc_next03));

    pe pe10(.north_in(south00), .west_in(a_west1), .accum_in(acc10),
            .south_out(south_next10), .east_out(east_next10), .result_next(acc_next10));
    pe pe11(.north_in(south01), .west_in(east10), .accum_in(acc11),
            .south_out(south_next11), .east_out(east_next11), .result_next(acc_next11));
    pe pe12(.north_in(south02), .west_in(east11), .accum_in(acc12),
            .south_out(south_next12), .east_out(east_next12), .result_next(acc_next12));
    pe pe13(.north_in(south03), .west_in(east12), .accum_in(acc13),
            .south_out(south_next13), .east_out(east_next13), .result_next(acc_next13));

    pe pe20(.north_in(south10), .west_in(a_west2), .accum_in(acc20),
            .south_out(south_next20), .east_out(east_next20), .result_next(acc_next20));
    pe pe21(.north_in(south11), .west_in(east20), .accum_in(acc21),
            .south_out(south_next21), .east_out(east_next21), .result_next(acc_next21));
    pe pe22(.north_in(south12), .west_in(east21), .accum_in(acc22),
            .south_out(south_next22), .east_out(east_next22), .result_next(acc_next22));
    pe pe23(.north_in(south13), .west_in(east22), .accum_in(acc23),
            .south_out(south_next23), .east_out(east_next23), .result_next(acc_next23));

    pe pe30(.north_in(south20), .west_in(a_west3), .accum_in(acc30),
            .south_out(south_next30), .east_out(east_next30), .result_next(acc_next30));
    pe pe31(.north_in(south21), .west_in(east30), .accum_in(acc31),
            .south_out(south_next31), .east_out(east_next31), .result_next(acc_next31));
    pe pe32(.north_in(south22), .west_in(east31), .accum_in(acc32),
            .south_out(south_next32), .east_out(east_next32), .result_next(acc_next32));
    pe pe33(.north_in(south23), .west_in(east32), .accum_in(acc33),
            .south_out(south_next33), .east_out(east_next33), .result_next(acc_next33));

    systolic_done_control done_control_i(
        .cycle_count(cycle_count),
        .done_in(done),
        .cycle_count_next(cycle_count_next),
        .done_next(done_next)
    );

    result_mapper_4x4 result_mapper_i(
        .acc00(acc00), .acc01(acc01), .acc02(acc02), .acc03(acc03),
        .acc10(acc10), .acc11(acc11), .acc12(acc12), .acc13(acc13),
        .acc20(acc20), .acc21(acc21), .acc22(acc22), .acc23(acc23),
        .acc30(acc30), .acc31(acc31), .acc32(acc32), .acc33(acc33),
        .result0(result0), .result1(result1), .result2(result2), .result3(result3),
        .result4(result4), .result5(result5), .result6(result6), .result7(result7),
        .result8(result8), .result9(result9), .result10(result10), .result11(result11),
        .result12(result12), .result13(result13), .result14(result14), .result15(result15)
    );

    initial begin
        cycle_count = 4'd0;
        done = 1'b0;

        east00 = 32'd0; east01 = 32'd0; east02 = 32'd0; east03 = 32'd0;
        east10 = 32'd0; east11 = 32'd0; east12 = 32'd0; east13 = 32'd0;
        east20 = 32'd0; east21 = 32'd0; east22 = 32'd0; east23 = 32'd0;
        east30 = 32'd0; east31 = 32'd0; east32 = 32'd0; east33 = 32'd0;

        south00 = 32'd0; south01 = 32'd0; south02 = 32'd0; south03 = 32'd0;
        south10 = 32'd0; south11 = 32'd0; south12 = 32'd0; south13 = 32'd0;
        south20 = 32'd0; south21 = 32'd0; south22 = 32'd0; south23 = 32'd0;
        south30 = 32'd0; south31 = 32'd0; south32 = 32'd0; south33 = 32'd0;

        acc00 = 64'd0; acc01 = 64'd0; acc02 = 64'd0; acc03 = 64'd0;
        acc10 = 64'd0; acc11 = 64'd0; acc12 = 64'd0; acc13 = 64'd0;
        acc20 = 64'd0; acc21 = 64'd0; acc22 = 64'd0; acc23 = 64'd0;
        acc30 = 64'd0; acc31 = 64'd0; acc32 = 64'd0; acc33 = 64'd0;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 4'd0;
            done <= 1'b0;

            east00 <= 32'd0; east01 <= 32'd0; east02 <= 32'd0; east03 <= 32'd0;
            east10 <= 32'd0; east11 <= 32'd0; east12 <= 32'd0; east13 <= 32'd0;
            east20 <= 32'd0; east21 <= 32'd0; east22 <= 32'd0; east23 <= 32'd0;
            east30 <= 32'd0; east31 <= 32'd0; east32 <= 32'd0; east33 <= 32'd0;

            south00 <= 32'd0; south01 <= 32'd0; south02 <= 32'd0; south03 <= 32'd0;
            south10 <= 32'd0; south11 <= 32'd0; south12 <= 32'd0; south13 <= 32'd0;
            south20 <= 32'd0; south21 <= 32'd0; south22 <= 32'd0; south23 <= 32'd0;
            south30 <= 32'd0; south31 <= 32'd0; south32 <= 32'd0; south33 <= 32'd0;

            acc00 <= 64'd0; acc01 <= 64'd0; acc02 <= 64'd0; acc03 <= 64'd0;
            acc10 <= 64'd0; acc11 <= 64'd0; acc12 <= 64'd0; acc13 <= 64'd0;
            acc20 <= 64'd0; acc21 <= 64'd0; acc22 <= 64'd0; acc23 <= 64'd0;
            acc30 <= 64'd0; acc31 <= 64'd0; acc32 <= 64'd0; acc33 <= 64'd0;
        end else begin
            cycle_count <= cycle_count_next;
            done <= done_next;

            east00 <= east_next00; east01 <= east_next01; east02 <= east_next02; east03 <= east_next03;
            east10 <= east_next10; east11 <= east_next11; east12 <= east_next12; east13 <= east_next13;
            east20 <= east_next20; east21 <= east_next21; east22 <= east_next22; east23 <= east_next23;
            east30 <= east_next30; east31 <= east_next31; east32 <= east_next32; east33 <= east_next33;

            south00 <= south_next00; south01 <= south_next01; south02 <= south_next02; south03 <= south_next03;
            south10 <= south_next10; south11 <= south_next11; south12 <= south_next12; south13 <= south_next13;
            south20 <= south_next20; south21 <= south_next21; south22 <= south_next22; south23 <= south_next23;
            south30 <= south_next30; south31 <= south_next31; south32 <= south_next32; south33 <= south_next33;

            acc00 <= acc_next00; acc01 <= acc_next01; acc02 <= acc_next02; acc03 <= acc_next03;
            acc10 <= acc_next10; acc11 <= acc_next11; acc12 <= acc_next12; acc13 <= acc_next13;
            acc20 <= acc_next20; acc21 <= acc_next21; acc22 <= acc_next22; acc23 <= acc_next23;
            acc30 <= acc_next30; acc31 <= acc_next31; acc32 <= acc_next32; acc33 <= acc_next33;
        end
    end

endmodule