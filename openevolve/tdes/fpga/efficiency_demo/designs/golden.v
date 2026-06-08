// Golden reference: complex multiply (a_r + a_i*i) * (b_r + b_i*i).
// The functional SPEC — the equivalence oracle every candidate is proven against.
// Straightforward 4-multiplier form.
module cmul(
    input  signed [3:0] ar,
    input  signed [3:0] ai,
    input  signed [3:0] br,
    input  signed [3:0] bi,
    output signed [15:0] yr,
    output signed [15:0] yi
);
    assign yr = ar * br - ai * bi;  // real part
    assign yi = ar * bi + ai * br;  // imag part
endmodule
