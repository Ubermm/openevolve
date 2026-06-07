# TDES-CombOpt: evolving NP-hard heuristics that beat exact solvers under budget

This layer tests the question: *can TDES evolve heuristics that improve over
traditional methods/solvers, and work in conjunction with a downstream exact
method to beat what the solver achieves alone?* — the AlphaEvolve/FunSearch
template applied to two NP-hard problems (Maximum Independent Set, Max-Cut).

The unit evolved is a `priority(v, graph)` function plugged into a **fixed,
trusted harness** that guarantees feasibility and recomputes the objective
exactly (the LLM never emits a solution, only a ranking heuristic). The downstream
exact method is **OR-Tools CP-SAT**; the headline SYSTEM test warm-starts CP-SAT
with the evolved heuristic's solution and checks the hybrid beats the **cold**
solver under the *same deterministic budget*.

Everything is reproducible: graph instances are seeded; CP-SAT runs single-worker
with a fixed seed and a **deterministic** time budget (`max_deterministic_time`,
so warm-vs-cold does not depend on machine speed/load).

## 1. The hybrid beats the budgeted exact solver (deterministic, no LLM)

Offline check (`_validate.py`) comparing, on held-out SYSTEM instances under a
fixed deterministic CP-SAT budget: the **cold** solver, the classical-baseline
heuristic warm-start, and the strong reference heuristic warm-start (hybrid keeps
`max(heuristic, warm-solver)` — never worse than the feasible hint).

| Problem | cold CP-SAT | baseline-heuristic hybrid | strong-heuristic hybrid |
|---|---|---|---|
| **MIS** (budget 0.08, 4 inst)    | 376  | 373 (loses) | **379 (beats)** |
| **Max-Cut** (budget 0.08, 3 inst)| 6267 | 6544 (beats) | **6544 (beats)** |

Two complementary regimes:

* **MIS — competent-solver regime.** Cold CP-SAT is strong (376), so the *weak*
  baseline heuristic's hybrid actually *loses* (373) — only a genuinely good
  evolved heuristic's hybrid beats the solver (379). A **tight** gate: it
  certifies the heuristic is better than the solver's own budgeted search, not
  just better than nothing.
* **Max-Cut — hard-for-the-solver regime.** CP-SAT is weak on Max-Cut (a notori­
  ously hard ILP), so even a mediocre heuristic's hybrid (6544) beats the cold
  solver (6267) comfortably; a strong move-selection heuristic widens the margin.

Both support the thesis: *the evolved heuristic + the downstream exact solver
beats the exact solver alone under a fixed budget.* The MIS adaptive heuristic
also **strictly beats the classical baseline** on every class (sparse 32.0 vs
30.7, dense 7.3 vs 6.7, clustered 19.0 vs 18.3 mean IS size).

## 2. Method comparison with a real LLM (Claude Sonnet 4.6)

Full hierarchical suite (9 unit + 3 integration + 1 SYSTEM = 13 tests; *solved*
means all 13 pass, including the hybrid-beats-CP-SAT gate). TDES uses full
per-candidate repair (the fair setting: same repair throughput as single-agent,
plus a population and crossover). pop=4, gens=5; single-agent rounds=5; pass@5
k=5. Per (problem, seed) solved:

| Problem | TDES (s0, s1) | single-agent (s0, s1) | pass@5 (s0, s1) |
|---|---|---|---|
| MIS      | ✓ ✓ | ✓ ✓ | ✓ ✓ |
| Max-Cut  | ✓ ✗* | ✓ ✓ | ✗ ✗ |
| **cells solved** | **3/4** | **4/4** | **2/4** |

`*` The Max-Cut/TDES/seed-1 cell ran during a ~2-hour network outage (8 logged
connection errors) that starved its LLM calls; it reached 12/13. The clean
pre-outage cells are seed 0, where **TDES = single-agent = 100%** and one-shot
**pass@5 = 50%** (it never solves Max-Cut at either seed).

**Takeaways.** (a) Iterative-feedback methods (TDES, single-agent) solve designs
that one-shot pass@5 cannot — pass@5 fails Max-Cut at both seeds, exactly the
"the CEGIS feedback loop is doing the work" result. (b) With the fair full-repair
setting TDES matches single-agent (both pass the SYSTEM hybrid gate); TDES does
not *beat* single-agent here, because these portfolios are small enough that one
lineage's repair suffices — crossover's value shows under a tighter budget (§3),
the regime the paper targets. (c) Both solving 13/13 means **the evolved heuristic
portfolios, used to warm-start CP-SAT, beat the cold solver** — the §1 thesis,
now reached from a weak seed by a real LLM.

## 3. Crossover: mechanism and necessity

The portfolio (one heuristic per instance class: sparse / dense / clustered) is
the multi-module structure complementary-coverage crossover targets — a candidate
strong on one class and weak on another passes a strict subset of the unit tests,
and crossover grafts the donor's class specialist.

**Mechanism (offline, scripted reference, units+integration suite,
`crossover_ablation.py`, 3 seeds):** complementary-coverage crossover fires and is
accepted at **100%**:

| Problem | budget | crossover accepted / attempted |
|---|---|---|
| MIS     | gens=2 | 6/6 |
| MIS     | gens=5 | 8/8 |
| Max-Cut | gens=2 | 4/4 |
| Max-Cut | gens=5 | 4/4 |

A direct unit test (`test_complementary_graft_accepts`) shows a clustered-special­
ist and a sparse-specialist crossed into a portfolio passing both classes' tests
plus all integration tests — a jump (+5 tests) no single mutation made.

**Necessity (real LLM, tight budget gens=3, one class repaired per candidate per
generation, `run_crossover_llm.py`, 3 seeds):** here crossover did **not** fire —
0 attempts — and `tdes_full` ≈ `tdes_no_crossover`:

| Problem | tdes_full (solved, mean passes) | tdes_no_crossover | crossover acc/att |
|---|---|---|---|
| MIS     | 2/3, 11.0/12 | 2/3, 10.7/12 | 0/0 |
| Max-Cut | 1/3, 10.3/12 | 1/3, 10.3/12 | 0/0 |

This is reported honestly rather than hidden: with the *scripted* mutator the
population diversifies cleanly into class specialists and crossover fires at 100%
acceptance (table above), but the LLM's noisier mutation here converges to
*nested* coverage (each surviving lineage's passes are a superset of the next)
rather than the *complementary* coverage crossover requires, so it stays inert.
That is consistent with §2: on these small 3-class portfolios a single lineage's
repair already suffices, so there is little complementary structure to exploit.
**The budget-constrained necessity result for complementary-coverage crossover is
the multi-module RTL result in the FPGA layer (`fpga/experiments/RESULTS.md` §3);
for CombOpt the crossover claim is the validated *mechanism*, not necessity.**

## Honesty notes

* The SYSTEM test keeps `max(heuristic, warm-solver)` rather than trusting
  CP-SAT's `AddHint` blindly — under tiny budgets the hint is not always repaired
  into the incumbent, so warm alone can occasionally underperform cold. Keeping
  the better of the two is exactly standard practice and makes the gate honest.
* Max-Cut's evolved lever is **local-search move selection** (which improving
  flip to take), not greedy ordering — greedy max-cut ordering has near-zero,
  noisy leverage. Max-Cut's strong reference *matches* the classical steepest-
  ascent rule (the seed, a constant selector, fails); MIS's strong reference
  *strictly beats* its classical baseline. So the "beats the traditional
  heuristic" claim rests on MIS; Max-Cut carries the "beats the budgeted solver"
  claim most strongly.
* `dense` MIS is excluded from the SYSTEM set: cold CP-SAT collapses to the empty
  set there (objective 0), so any heuristic trivially beats it — not a meaningful
  gate. Dense competence is still required by the unit and integration tests.

## Reproduce

```bash
pip install ortools
python -m openevolve.tdes.combopt._validate mis      # §1, deterministic
python -m openevolve.tdes.combopt._validate maxcut
python -m openevolve.tdes.combopt.experiments.crossover_ablation mis   # §3 mechanism
ANTHROPIC_API_KEY=... python -m openevolve.tdes.combopt.experiments.run_combopt \
    --config openevolve/tdes/combopt/experiments/configs/anthropic_sonnet.yaml \
    --problems mis maxcut --conditions tdes_full single_agent pass5 --seeds 0   # §2
ANTHROPIC_API_KEY=... python -m openevolve.tdes.combopt.experiments.run_crossover_llm \
    --config .../configs/anthropic_sonnet.yaml --gens 2 --seeds 0 1 2           # §3 necessity
```
