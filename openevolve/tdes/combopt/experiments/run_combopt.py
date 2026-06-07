"""
TDES-CombOpt method comparison: TDES vs single-agent vs pass@5 on Max-Cut / MIS.

    python -m openevolve.tdes.combopt.experiments.run_combopt \
        --config .../configs/anthropic_sonnet.yaml \
        --problems mis maxcut --conditions tdes_full single_agent pass5 --seeds 0 1

Uses the full hierarchical suite (units + per-class integration + the SYSTEM
hybrid gate). The SYSTEM test is the headline: the evolved heuristic portfolio,
used to warm-start CP-SAT, must beat the cold solver under the same budget.
"""

from __future__ import annotations

import argparse
import logging
import os
import sys

from openevolve.tdes.combopt.experiments import runner
from openevolve.tdes.config import TDESConfig
from openevolve.tdes.fpga import metrics

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="TDES-CombOpt method comparison")
    p.add_argument("--config", required=True)
    p.add_argument("--problems", nargs="*", default=["mis", "maxcut"])
    p.add_argument("--conditions", nargs="*", default=["tdes_full", "single_agent", "pass5"])
    p.add_argument("--seeds", nargs="*", type=int, default=[0])
    p.add_argument("--out", default="tdes_combopt_results/method_comparison.json")
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    config = TDESConfig.from_yaml(args.config)

    results = runner.run_matrix(
        args.problems, args.conditions, config, seeds=args.seeds, scripted=False
    )

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    metrics.save_metrics(results, args.out)
    print("\n## Method comparison (CombOpt)\n")
    print(metrics.render_table1(results, args.conditions))
    print("\n## Crossover analysis\n")
    print(metrics.render_table2(results))
    print(f"\nraw metrics -> {os.path.abspath(args.out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
