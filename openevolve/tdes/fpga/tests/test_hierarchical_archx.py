"""Tests for the real multi-module crossover harness (Experiment 2).

Gated on Icarus Verilog (the OSS CAD Suite). They prove the mechanism Exp 2 rests
on: for every published ArchXBench hierarchical design the authored 3-tier suite
is *reference-sound* (the golden {TOP, SUB} passes all tiers, the skeleton fails),
and a complementary partial pair — A(good SUB/bad TOP) + B(bad SUB/good TOP) —
exhibits complementary test coverage that ``complementary_crossover`` resolves
into an all-pass child. That is crossover firing on a published benchmark, not a
synthetic problem.
"""

import unittest

from openevolve.tdes import selection
from openevolve.tdes.crossover import complementary_crossover
from openevolve.tdes.fpga import benchmark_loader, verilog_runner
from openevolve.tdes.fpga.experiments import hierarchical_archx as H
from openevolve.tdes.types import Candidate

_TIMEOUT = 180


@unittest.skipUnless(verilog_runner.tools_available(), "iverilog/vvp not on PATH")
class TestHierReferenceSound(unittest.TestCase):
    def test_reference_passes_all_tiers_and_skeleton_fails(self):
        for key in H.DESIGNS:
            with self.subTest(design=key):
                d = H.get(key)
                seed, suite, _ = H.load_hierarchical(key)
                self.assertEqual(len(suite.tests), 3)
                ref = Candidate(modules={d.top: d.top_golden, d.sub: d.sub_golden})
                rv = suite.run(ref, timeout=_TIMEOUT)
                self.assertEqual(rv.total_passes, len(suite.tests), f"{key} reference")
                sv = suite.run(seed, timeout=_TIMEOUT)
                self.assertLess(sv.total_passes, rv.total_passes, f"{key} skeleton")
                self.assertTrue(benchmark_loader.is_usable(seed, suite, timeout=_TIMEOUT))


@unittest.skipUnless(verilog_runner.tools_available(), "iverilog/vvp not on PATH")
class TestHierCrossoverFires(unittest.TestCase):
    def test_complementary_partial_pair_crosses_over_to_solution(self):
        for key in H.DESIGNS:
            with self.subTest(design=key):
                d = H.get(key)
                _, suite, _ = H.load_hierarchical(key)
                # A: good SUB, bad TOP -> passes the UNIT tier only.
                a = Candidate(modules={d.top: d.top_skeleton, d.sub: d.sub_golden})
                # B: bad SUB, good TOP -> passes the INTEGRATION tier only
                #    (golden SUB injected inline; candidate SUB never compiled there).
                b = Candidate(modules={d.top: d.top_golden, d.sub: d.sub_skeleton})
                a.vector = suite.run(a, timeout=_TIMEOUT)
                b.vector = suite.run(b, timeout=_TIMEOUT)

                # Neither solves alone; coverage is complementary (disjoint, nonempty).
                self.assertLess(a.vector.total_passes, len(suite.tests))
                self.assertLess(b.vector.total_passes, len(suite.tests))
                self.assertTrue(a.vector.passes())
                self.assertTrue(b.vector.passes())
                self.assertEqual(a.vector.passes() & b.vector.passes(), set())

                higher, lower = selection.rank([a, b])
                outcome = complementary_crossover(
                    higher, lower, suite, generation=1, timeout=_TIMEOUT
                )
                self.assertTrue(outcome.accepted, f"{key} crossover not accepted")
                self.assertEqual(outcome.child.vector.total_passes, len(suite.tests))


@unittest.skipUnless(verilog_runner.tools_available(), "iverilog/vvp not on PATH")
class TestIsolateModules(unittest.TestCase):
    def test_integration_tier_ignores_candidate_submodule(self):
        # The INTEGRATION tier must score the TOP independently of the candidate's
        # SUB: a broken candidate SUB alongside a correct TOP still passes it,
        # because only the TOP is compiled (the golden SUB lives in the tb).
        d = H.get("comparator-8bit")
        _, suite, _ = H.load_hierarchical("comparator-8bit")
        cand = Candidate(modules={d.top: d.top_golden, d.sub: d.sub_skeleton})
        vec = suite.run(cand, timeout=_TIMEOUT)
        integ = vec.results[f"{d.top}_integ"]
        system = vec.results[f"{d.top}_system"]
        self.assertTrue(integ.passed)  # top wiring fine despite broken sub
        self.assertFalse(system.passed)  # whole design needs a real sub


if __name__ == "__main__":
    unittest.main()
