"""Tests for the efficiency demo: formal equivalence gate + area-gated suite.

Gated on Yosys (the OSS CAD Suite). They prove the mechanism the demo rests on:
the equivalence oracle accepts equivalent rewrites and rejects wrong ones, and
the suite ranks a smaller-correct design above the seed and a smaller-wrong one
below it.
"""

import os
import unittest

from openevolve.tdes.fpga import equivalence, synthesis
from openevolve.tdes.fpga.efficiency_demo.efficiency_suite import EfficiencySuite
from openevolve.tdes.types import Candidate

_DESIGNS = os.path.join(os.path.dirname(os.path.dirname(__file__)), "efficiency_demo", "designs")


def _read(name):
    with open(os.path.join(_DESIGNS, f"{name}.v"), encoding="utf-8") as f:
        return f.read()


@unittest.skipUnless(synthesis.yosys_available(), "yosys not on PATH")
class TestEquivalenceGate(unittest.TestCase):
    def setUp(self):
        self.golden = _read("golden")

    def test_seed_is_equivalent(self):
        r = equivalence.check_equivalence(_read("seed"), self.golden, top="cmul")
        self.assertTrue(r.ok)
        self.assertTrue(r.equivalent)

    def test_karatsuba_is_equivalent(self):
        r = equivalence.check_equivalence(_read("karatsuba"), self.golden, top="cmul")
        self.assertTrue(r.equivalent)

    def test_evolved_gauss_is_equivalent(self):
        r = equivalence.check_equivalence(_read("evolved_gauss"), self.golden, top="cmul")
        self.assertTrue(r.equivalent)

    def test_broken_is_rejected_with_counterexample(self):
        r = equivalence.check_equivalence(_read("broken"), self.golden, top="cmul")
        self.assertTrue(r.ok)
        self.assertFalse(r.equivalent)
        self.assertTrue(r.counterexample)


@unittest.skipUnless(synthesis.yosys_available(), "yosys not on PATH")
class TestEfficiencySuite(unittest.TestCase):
    def setUp(self):
        self.suite = EfficiencySuite(
            module="cmul", golden_source=_read("golden"), top="cmul", mul_budget=3
        )

    def _run(self, name):
        return self.suite.run(Candidate(modules={"cmul": _read(name)}), timeout=180)

    def test_multiplier_counts(self):
        for name, expected in (("seed", 4), ("karatsuba", 3), ("evolved_gauss", 3)):
            r = synthesis.rtl_cell_counts({"cmul": _read(name)}, top_module="cmul")
            self.assertEqual(synthesis.multiplier_count(r), expected, name)

    def test_seed_passes_equiv_not_area(self):
        v = self._run("seed")
        self.assertTrue(v.results["unit:equiv"].passed)
        self.assertFalse(v.results["system:area-mul<=3"].passed)
        self.assertEqual(v.score_key, (0, 0, 1))

    def test_karatsuba_solves(self):
        v = self._run("karatsuba")
        self.assertEqual(v.total_passes, len(self.suite.tests))
        self.assertEqual(v.score_key, (1, 0, 1))

    def test_broken_ranks_below_seed(self):
        # Smaller but wrong: must NOT earn the area (system) pass.
        broken = self._run("broken")
        seed = self._run("seed")
        self.assertEqual(broken.score_key, (0, 0, 0))
        self.assertGreater(seed.score_key, broken.score_key)


if __name__ == "__main__":
    unittest.main()
