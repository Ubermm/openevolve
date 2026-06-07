"""
Offline tests for the TDES-CombOpt layer (no API key required).

Covers: the fixed harnesses + exact feasibility/verification, the CP-SAT exact
solvers (gated on ortools), the drop-in suite (seed weak / reference strong),
complementary-coverage crossover grafting class specialists, and one end-to-end
controller run with the scripted reference mutator.
"""

from __future__ import annotations

import unittest

from openevolve.tdes.combopt import benchmark_loader, heuristic_runner
from openevolve.tdes.combopt.problems import MIS, MaxCut, get_problem
from openevolve.tdes.types import Candidate, TestLevel

try:
    from ortools.sat.python import cp_model  # noqa: F401

    HAVE_ORTOOLS = True
except Exception:  # pragma: no cover
    HAVE_ORTOOLS = False


def _compile(src):
    fn, err = heuristic_runner._compile_priority(src)
    assert fn is not None, err
    return fn


class TestHarnessFeasibility(unittest.TestCase):
    def test_mis_harness_produces_independent_set(self):
        p = MIS()
        inst = p.generate("dense", 40, 1)
        fn = _compile(benchmark_loader.REFERENCE_SOURCES["mis"])
        res = p.run(fn, inst)
        self.assertTrue(res.feasible)
        ok, reason = p.verify(inst, res.solution)
        self.assertTrue(ok, reason)
        # objective recomputed exactly == set size
        self.assertEqual(res.quality, len(res.solution))

    def test_maxcut_harness_produces_valid_partition(self):
        p = MaxCut()
        inst = p.generate("clustered", 40, 2)
        fn = _compile(benchmark_loader.REFERENCE_SOURCES["maxcut"])
        res = p.run(fn, inst)
        self.assertTrue(res.feasible)
        ok, _ = p.verify(inst, res.solution)
        self.assertTrue(ok)
        # recomputed cut matches the reported quality
        self.assertAlmostEqual(res.quality, p.objective(inst, res.solution))

    def test_broken_priority_is_caught_not_crash(self):
        p = MIS()
        inst = p.generate("sparse", 20, 3)
        fn = _compile("def priority(v, graph):\n    return 1/0\n")
        res = p.run(fn, inst)
        self.assertFalse(res.feasible)
        self.assertIn("raised", res.error)

    def test_reference_beats_or_matches_baseline_mis(self):
        p = MIS()
        strong = _compile(benchmark_loader.REFERENCE_SOURCES["mis"])
        base = _compile(p.baseline_priority_source)
        wins = 0
        for cls in ("sparse", "clustered"):
            for s in range(3):
                inst = p.generate(cls, 60, 100 + s)
                if p.run(strong, inst).quality >= p.run(base, inst).quality:
                    wins += 1
        self.assertGreaterEqual(wins, 5)  # adaptive >= static on >=5/6


@unittest.skipUnless(HAVE_ORTOOLS, "ortools not installed")
class TestExactSolvers(unittest.TestCase):
    def test_mis_optimal_on_triangle(self):
        from openevolve.tdes.combopt import exact
        from openevolve.tdes.combopt.problems import Instance

        # Triangle: max independent set = 1.
        inst = Instance(id="tri", cls="x", n=3, edges=[(0, 1, 1.0), (1, 2, 1.0), (0, 2, 1.0)])
        r = exact.solve_mis(inst, 1.0)
        self.assertEqual(r.objective, 1)
        self.assertTrue(r.optimal)

    def test_maxcut_optimal_on_triangle(self):
        from openevolve.tdes.combopt import exact
        from openevolve.tdes.combopt.problems import Instance

        # Triangle: max cut = 2 (any 1-vs-2 split cuts two edges).
        inst = Instance(id="tri", cls="x", n=3, edges=[(0, 1, 1.0), (1, 2, 1.0), (0, 2, 1.0)])
        r = exact.solve_maxcut(inst, 1.0)
        self.assertEqual(r.objective, 2)

    def test_warm_start_never_worse_than_hint(self):
        from openevolve.tdes.combopt import exact

        p = MIS()
        inst = p.generate("sparse", 80, 7)
        fn = _compile(benchmark_loader.REFERENCE_SOURCES["mis"])
        g = p.run(fn, inst)
        hint = exact.mis_hint_from_set(inst.n, g.solution)
        warm = exact.solve_mis(inst, 0.2, hint=hint, deterministic=True)
        self.assertGreaterEqual(warm.objective, g.quality - 1e-6)


@unittest.skipUnless(HAVE_ORTOOLS, "ortools not installed")
class TestSuite(unittest.TestCase):
    def test_seed_weak_reference_strong(self):
        for name in ("mis", "maxcut"):
            seed, suite, _ = benchmark_loader.load_problem(name, with_mutator=True)
            seed_vec = suite.run(seed, sandbox=False)
            strong = benchmark_loader.REFERENCE_SOURCES[name]
            cand = Candidate(modules={c: strong for c in suite.module_names})
            strong_vec = suite.run(cand, sandbox=False)
            self.assertGreater(
                strong_vec.total_passes, seed_vec.total_passes, f"{name}: reference must beat seed"
            )
            # reference should pass the great majority of tests
            self.assertGreaterEqual(strong_vec.total_passes, len(suite.tests) - 1)

    def test_subprocess_and_inprocess_agree(self):
        seed, suite, _ = benchmark_loader.load_problem("mis", with_mutator=True)
        cand = Candidate(
            modules={c: benchmark_loader.REFERENCE_SOURCES["mis"] for c in suite.module_names}
        )
        v_in = suite.run(cand, sandbox=False)
        v_out = suite.run(cand, sandbox=True, timeout=120)
        self.assertEqual(v_in.passes(), v_out.passes())

    def test_levels_present(self):
        _, suite, _ = benchmark_loader.load_problem("mis")
        levels = {t.level for t in suite.tests}
        self.assertEqual(levels, {TestLevel.UNIT, TestLevel.INTEGRATION, TestLevel.SYSTEM})


@unittest.skipUnless(HAVE_ORTOOLS, "ortools not installed")
class TestCrossover(unittest.TestCase):
    def test_complementary_graft_accepts(self):
        from openevolve.tdes import selection
        from openevolve.tdes.crossover import complementary_crossover

        seed, suite, _ = benchmark_loader.load_problem("mis", include_system=False)
        strong = benchmark_loader.REFERENCE_SOURCES["mis"]
        weak = benchmark_loader.WEAK_SEED_SOURCE
        a = Candidate(modules={"sparse": strong, "dense": weak, "clustered": weak})
        b = Candidate(modules={"sparse": weak, "dense": weak, "clustered": strong})
        a.vector = suite.run(a, sandbox=False)
        b.vector = suite.run(b, sandbox=False)
        higher, lower = selection.rank([a, b])[0], selection.rank([a, b])[1]
        out = complementary_crossover(higher, lower, suite, generation=1, sandbox=False)
        self.assertTrue(out.attempted)
        self.assertTrue(out.accepted)
        # child strictly supersedes the higher parent's passes
        self.assertTrue(out.child.vector.is_strict_superset_of(higher.vector))


@unittest.skipUnless(HAVE_ORTOOLS, "ortools not installed")
class TestControllerIntegration(unittest.TestCase):
    def test_scripted_run_improves(self):
        from openevolve.tdes.combopt import ablation
        from openevolve.tdes.config import TDESConfig

        seed, suite, mutator = benchmark_loader.load_problem("mis", with_mutator=True)
        cfg = TDESConfig(
            pop_size=4,
            max_generations=4,
            sandbox=False,
            mutate_modules_per_candidate=1,
            random_seed=1,
            output_dir="tdes_combopt_results/_test",
        )
        ctrl = ablation.DiverseScheduleController(seed, suite, mutator, cfg)
        result = ctrl.run()
        self.assertGreater(result.best.vector.total_passes, 1)


if __name__ == "__main__":
    unittest.main()
