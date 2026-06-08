// A WRONG 3-multiplier rewrite (sign bug: yr should be k1 - k3, not k1 + k3).
// It is *smaller* than the golden (3 multipliers) yet functionally incorrect.
// Used by the deterministic validation to show the formal equivalence gate
// REJECTS it — area pressure alone would happily accept this cheat; the gate is
// what makes efficiency-driven evolution safe.
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
    assign yr = k1 + k3;  // BUG: must be k1 - k3
    assign yi = k1 + k2;
endmodule
