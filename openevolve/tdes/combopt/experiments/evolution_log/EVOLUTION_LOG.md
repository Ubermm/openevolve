# TDES-CombOpt evolution log

Per-generation source diffs along the best-of-generation lineage. Each run starts from the deliberately weak seed (`def priority(v, graph): return 0.0` for every instance class), so the diffs show the full discovery: from no class knowledge to the final portfolio that warm-starts CP-SAT. Captured by `experiments/snapshot.py` (Claude Sonnet 4.6, temp 0.9, pop=4, gens=5). MIS solves; Max-Cut is variance-prone at this temperature (cf. RESULTS.md §2) and this run stalled at 12/13 then escalated — its `escalation.json` (failing tests + negative memory) is kept.

| run | solved | final | gens | crossover acc/att |
|---|---|---|---|---|
| [mis seed 0](mis_seed0/README.md) | True | system 1, integration 3, unit 9 (13/13 total) | 2 | 0/0 |
| [maxcut seed 0](maxcut_seed0/README.md) | False | system 1, integration 1, unit 7 (9/13 total) | 3 | 0/0 |
