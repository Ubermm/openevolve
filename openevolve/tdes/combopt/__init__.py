"""
TDES-CombOpt: an additive layer that evolves *heuristics* for NP-hard
combinatorial problems (Max-Cut, Maximum Independent Set) and composes them with
a downstream **exact solver** (OR-Tools CP-SAT) — the FunSearch / AlphaEvolve
pattern of "evolve the priority function, never the solution; a deterministic
evaluator owns correctness".

The TDES controller / selection / crossover / memory are reused **unchanged**
(they are duck-typed against the suite). Only the test runner is swapped: a
candidate is a *portfolio* of per-instance-class priority functions, evaluated by
a fixed greedy harness with exact verification, plus a SYSTEM-level test that
warm-starts CP-SAT and checks it beats the cold solver under a fixed budget.

Do not modify base ``tdes/*`` files — extend via subclass/composition, as this
layer (and the FPGA layer) does.
"""
