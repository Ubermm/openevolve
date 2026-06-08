// LLM-DISCOVERED (Claude Sonnet 4.6, 2 generations) — NOT hand-written.
// Evolved from seed.v (4 multipliers) under the EfficiencySuite formal gate.
// It independently found the Gauss complex-multiplication algorithm (3 real
// multiplications) — a *different*, more canonical form than the Karatsuba
// reference in karatsuba.v — and it is SAT-proven equivalent to golden.v:
//   m1 = ar*br ; m2 = ai*bi ; m3 = (ar+ai)*(br+bi)
//   yr = m1 - m2       = ar*br - ai*bi
//   yi = m3 - m1 - m2  = ar*bi + ai*br
module cmul(
    input  signed [3:0] ar,
    input  signed [3:0] ai,
    input  signed [3:0] br,
    input  signed [3:0] bi,
    output signed [15:0] yr,
    output signed [15:0] yi
);
    wire signed [4:0] sum_a = ar + ai;
    wire signed [4:0] sum_b = br + bi;
    wire signed [15:0] m1 = ar * br;
    wire signed [15:0] m2 = ai * bi;
    wire signed [15:0] m3 = sum_a * sum_b;
    assign yr = m1 - m2;
    assign yi = m3 - m1 - m2;
endmodule