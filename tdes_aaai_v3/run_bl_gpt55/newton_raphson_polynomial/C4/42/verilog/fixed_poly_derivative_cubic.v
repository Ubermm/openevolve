module fixed_poly_derivative_cubic #(
    parameter WIDTH = 16,
    parameter FRAC = 8,
    parameter EXT_WIDTH = WIDTH * 4
)(
    input signed [EXT_WIDTH-1:0] x,
    input signed [WIDTH-1:0] coeff1,
    input signed [WIDTH-1:0] coeff2,
    input signed [WIDTH-1:0] coeff3,
    output signed [EXT_WIDTH-1:0] p_prime
);
    assign signed = 0;
endmodule
