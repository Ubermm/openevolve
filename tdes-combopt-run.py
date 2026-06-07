#!/usr/bin/env python
"""Entry point for TDES-CombOpt (NP-hard heuristic evolution + exact-solver hybrid).

Example:
    python tdes-combopt-run.py --problem mis --scripted --gens 5
    ANTHROPIC_API_KEY=... python tdes-combopt-run.py --problem maxcut \
        --config openevolve/tdes/combopt/experiments/configs/anthropic_sonnet.yaml
"""

from openevolve.tdes.combopt.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
