"""
Multi-module crossover demonstration for TDES-FPGA.

The complementary-coverage crossover (the paper's primary contribution) grafts
*modules* between candidates, so it can only fire on a **multi-module** codebase.
Single-module benchmark designs (e.g. most of RTLLM) exercise mutation + memory +
hierarchy but never crossover.

This script builds a tiny two-module Verilog problem (`adder8` + `cmp8`) with an
empty seed and a hierarchical suite (unit tests per module + an integration test
using both), then runs TDES with a real LLM. With a population and temperature,
different candidates fix different modules in early generations, producing
complementary test coverage that crossover grafts into a single passing
candidate. The script prints the crossover attempt/success statistics.

    export ANTHROPIC_API_KEY=...   OSS_CAD_SUITE_ROOT=...
    python -m openevolve.tdes.fpga.experiments.crossover_demo \
        --config openevolve/tdes/fpga/experiments/configs/anthropic_haiku.yaml
"""

from __future__ import annotations

import argparse
import logging

from typing import Optional

from openevolve.tdes.fpga import ablation
from openevolve.tdes.fpga.config import FPGAConfig
from openevolve.tdes.fpga.experiments import runner
from openevolve.tdes.fpga.verilog_suite import VerilogTest, VerilogTestSuite
from openevolve.tdes.types import Candidate, TestLevel


class DiverseScheduleController(ablation.AblationController):
    """AblationController that randomizes per-candidate module order.

    The base controller fixes failing modules in a fixed (test) order, so from a
    homogeneous seed every candidate pursues the same module first and the
    population never develops complementary coverage. Shuffling the order per
    candidate lets different candidates fix different modules — the diversity
    that complementary-coverage crossover needs to combine partial solutions.
    Only the per-candidate scheduling changes; all acceptance/regression rules
    are inherited unchanged.
    """

    async def _mutate_candidate(self, parent: Candidate, gen: int) -> Optional[Candidate]:
        baseline_passes = parent.passes
        working = parent.clone(generation=gen, parent_id=parent.id, metadata={"origin": "mutation"})
        working.vector = parent.vector
        changed = False

        failing_modules = parent.vector.failing_modules()
        self._rng.shuffle(failing_modules)  # <-- the only change vs. base
        limit = self.config.mutate_modules_per_candidate
        if limit is not None:
            failing_modules = failing_modules[:limit]

        for module in failing_modules:
            feedback = [
                r.feedback
                for r in working.vector.results.values()
                if not r.passed and r.module == module and r.feedback is not None
            ]
            proposal = await self.mutator.propose(
                candidate=working,
                module=module,
                feedback=feedback,
                memory_text=self.memory.render(module),
                generation=gen,
            )
            if proposal is None:
                continue
            trial = working.clone(generation=gen, parent_id=parent.id)
            trial.modules[module] = proposal.new_source
            trial.vector = self.suite.run(
                trial, sandbox=self.config.sandbox, timeout=self.config.suite_timeout
            )
            if trial.vector.is_superset_of(working.vector):
                if trial.vector.passes() != working.vector.passes():
                    changed = True
                working = trial
                working.metadata["origin"] = "mutation"
            else:
                self._record_failure(module, gen, proposal.approach, trial.vector, working)

        if changed and working.passes > baseline_passes:
            return working
        return working if changed else None


# Empty, compilable skeletons with the correct interface (no logic).
SEED = {
    "adder8": "module adder8(input [7:0] a, b, output [8:0] sum);\n  // TODO\nendmodule\n",
    "cmp8": "module cmp8(input [7:0] a, b, output gt);\n  // TODO\nendmodule\n",
}

_TB_ADD = """`timescale 1ns/1ps
module tb;
  reg [7:0] a, b; wire [8:0] sum;
  integer fails = 0;
  adder8 uut(.a(a), .b(b), .sum(sum));
  task chk(input [7:0] x, input [7:0] y, input [8:0] e);
    begin a=x; b=y; #5;
      if (sum !== e) begin
        $display("TDES_FAIL: test_id=%s | input=a=%0d,b=%0d | expected=%0d | got=%0d", "TID", x, y, e, sum);
        fails = fails + 1; end
    end
  endtask
  initial begin chk(3,4,9'd7); chk(8'd255,8'd1,9'd256); chk(0,0,0);
    if (fails==0) $display("TDES_PASS: test_id=TID"); $finish; end
endmodule
"""

_TB_CMP = """`timescale 1ns/1ps
module tb;
  reg [7:0] a, b; wire gt;
  integer fails = 0;
  cmp8 uut(.a(a), .b(b), .gt(gt));
  task chk(input [7:0] x, input [7:0] y, input e);
    begin a=x; b=y; #5;
      if (gt !== e) begin
        $display("TDES_FAIL: test_id=%s | input=a=%0d,b=%0d | expected=%0d | got=%0d", "TID", x, y, e, gt);
        fails = fails + 1; end
    end
  endtask
  initial begin chk(5,3,1'b1); chk(2,9,1'b0); chk(4,4,1'b0);
    if (fails==0) $display("TDES_PASS: test_id=TID"); $finish; end
endmodule
"""

_TB_BOTH = """`timescale 1ns/1ps
module tb;
  reg [7:0] a, b; wire [8:0] sum; wire gt;
  adder8 ua(.a(a), .b(b), .sum(sum));
  cmp8 uc(.a(a), .b(b), .gt(gt));
  initial begin
    a=8'd10; b=8'd5; #5;
    if (sum===9'd15 && gt===1'b1) $display("TDES_PASS: test_id=TID");
    else $display("TDES_FAIL: test_id=TID | input=a=10,b=5 | expected=sum=15,gt=1 | got=sum=%0d,gt=%0d", sum, gt);
    $finish;
  end
endmodule
"""


def build_suite() -> VerilogTestSuite:
    def tb(src, tid):
        return src.replace("TID", tid)

    tests = [
        VerilogTest(
            "u_add", TestLevel.UNIT, "adder8", "8-bit adder sum (a+b)", tb(_TB_ADD, "u_add")
        ),
        VerilogTest(
            "u_cmp", TestLevel.UNIT, "cmp8", "8-bit greater-than compare", tb(_TB_CMP, "u_cmp")
        ),
        VerilogTest(
            "i_both",
            TestLevel.INTEGRATION,
            "adder8",
            "adder8 and cmp8 agree on a=10,b=5",
            tb(_TB_BOTH, "i_both"),
            modules=["adder8", "cmp8"],
        ),
    ]
    return VerilogTestSuite(module_names=["adder8", "cmp8"], tests=tests, top_module="adder8")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="TDES-FPGA crossover demonstration")
    p.add_argument("--config", required=True)
    p.add_argument("--pop", type=int, default=6)
    p.add_argument("--gens", type=int, default=4)
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    config = FPGAConfig.from_yaml(args.config)
    config.pop_size = args.pop
    config.max_generations = args.gens
    config.random_seed = args.seed
    # Limit each candidate to fixing one module per generation, so partial
    # solutions accumulate in the population and complementary-coverage
    # crossover is the mechanism that combines them (rather than a single
    # candidate solving every module on its own).
    config.mutate_modules_per_candidate = 1

    ensemble = runner.build_ensemble(config)
    from openevolve.tdes.fpga.mutation import VerilogLLMMutator

    seed = Candidate(modules=dict(SEED))
    suite = build_suite()
    controller = DiverseScheduleController(
        seed, suite, VerilogLLMMutator(ensemble, diff_based=config.diff_based), config
    )
    result = controller.run()

    print("\n=== Crossover demonstration ===")
    print(
        f"best: {result.best.vector.summary()} (solved={result.best.vector.total_passes == len(suite.tests)})"
    )
    print(f"crossover stats: {controller.crossover_stats.as_dict()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
