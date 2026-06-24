module fixed_poly_eval_cubic #(
    parameter WIDTH = 16,
    parameter FRAC = 8,
    parameter EXT_WIDTH = WIDTH * 4
)(
    input  signed [EXT_WIDTH-1:0] x,
    input  signed [WIDTH-1:0]     coeff0,
    input  signed [WIDTH-1:0]     coeff1,
    input  signed [WIDTH-1:0]     coeff2,
    input  signed [WIDTH-1:0]     coeff3,
    output signed [EXT_WIDTH-1:0] p
);

    wire signed [EXT_WIDTH-1:0] c0_ext;
    wire signed [EXT_WIDTH-1:0] c1_ext;
    wire signed [EXT_WIDTH-1:0] c2_ext;
    wire signed [EXT_WIDTH-1:0] c3_ext;

    wire signed [EXT_WIDTH-1:0] horner_2;
    wire signed [EXT_WIDTH-1:0] horner_1;
    wire signed [EXT_WIDTH-1:0] horner_0;

    assign c0_ext = {{(EXT_WIDTH-WIDTH){coeff0[WIDTH-1]}}, coeff0};
    assign c1_ext = {{(EXT_WIDTH-WIDTH){coeff1[WIDTH-1]}}, coeff1};
    assign c2_ext = {{(EXT_WIDTH-WIDTH){coeff2[WIDTH-1]}}, coeff2};
    assign c3_ext = {{(EXT_WIDTH-WIDTH){coeff3[WIDTH-1]}}, coeff3};

    function signed [EXT_WIDTH-1:0] fixed_mul;
        input signed [EXT_WIDTH-1:0] a;
        input signed [EXT_WIDTH-1:0] b;
        reg signed [(2*EXT_WIDTH)-1:0] product;
        begin
            product = a * b;
            fixed_mul = product >>> FRAC;
        end
    endfunction

    assign horner_2 = fixed_mul(c3_ext, x) + c2_ext;
    assign horner_1 = fixed_mul(horner_2, x) + c1_ext;
    assign horner_0 = fixed_mul(horner_1, x) + c0_ext;

    assign p = horner_0;

endmodule