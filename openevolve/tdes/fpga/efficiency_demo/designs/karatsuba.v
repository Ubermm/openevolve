// TARGET discovery: the 3-multiplier complex multiply (Gauss/Karatsuba trick).
//   k1 = br*(ar + ai)
//   k2 = ar*(bi - br)
//   k3 = ai*(br + bi)
//   yr = k1 - k3 = ar*br - ai*bi
//   yi = k1 + k2 = ar*bi + ai*br
// Functionally identical to golden, but THREE multipliers instead of four —
// the "removed unnecessary arithmetic" AlphaEvolve-style win. Provided so the
// deterministic validation can show the formal gate ACCEPTS it (equivalent) and
// synthesis confirms the multiplier saving.
module cmul(
    input  signed [3:0] ar,
    input  signed [3:0] ai,
    input  signed [3:0] br,
    input  signed [3:0] bi,
    output signed [15:0] yr,
    output signed [15:0] yi
);
    wire signed [15:0] k1 = br * (ar + ai);
    wire signed [15:0] k2 = ar * (bi - br);
    wire signed [15:0] k3 = ai * (br + bi);
    assign yr = k1 - k3;
    assign yi = k1 + k2;
endmodule
