// Evolution SEED: a correct complex multiplier, identical to the golden spec.
// It uses FOUR multipliers (ar*br, ai*bi, ar*bi, ai*br). The task is to evolve a
// functionally-equivalent rewrite that uses fewer multipliers — the area win
// must be proven safe by the formal equivalence gate, exactly as AlphaEvolve's
// TPU rewrite had to pass robust verification.
module cmul(
    input  signed [3:0] ar,
    input  signed [3:0] ai,
    input  signed [3:0] br,
    input  signed [3:0] bi,
    output signed [15:0] yr,
    output signed [15:0] yi
);
    wire signed [15:0] m_arbr = ar * br;
    wire signed [15:0] m_aibi = ai * bi;
    wire signed [15:0] m_arbi = ar * bi;
    wire signed [15:0] m_aibr = ai * br;
    assign yr = m_arbr - m_aibi;
    assign yi = m_arbi + m_aibr;
endmodule
