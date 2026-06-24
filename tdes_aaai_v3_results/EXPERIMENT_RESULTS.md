# TDES-FPGA AAAI 2027 Experiment Results

## Experiment Configuration

- **Condition C2g**: Monolithic Golden CEGIS — multi-turn conversation with golden comparison feedback, 30 rounds max
- **Condition C1**: Zero-shot Pass@5 — 5 independent generation attempts, no feedback (baseline)
- **Models**: gpt-5.5 (frontier), o4-mini (reasoning), gpt-4o (medium) — all OpenAI
- **Seeds**: 42, 123, 456
- **Benchmark**: ArchXBench L2–L6 (32 designs total)
- **Infrastructure**: AWS EC2 c5.xlarge, iverilog/vvp for simulation
- **Parallelism**: 3 concurrent cells per model

> **Note**: `multich_conv2d` (L6) excluded from all results due to benchmark testbench naming issue (`testbench.v` vs expected `tb.v`). All cells crash before any LLM call. Effective L6 = 8 designs.

## Design Inventory

| Level | # Designs | Designs |
|-------|-----------|---------|
| L2 | 5 | aes128_single_round, cla_32bit_pipe, dadda_mult_pipe, rca_32bit_pipe, wallace_tree_mult_pipe |
| L3 | 6 | fp_adder, fp_multiplier, gauss_siedel, gradient_descent, newton_raphson_polynomial, newton_raphson_sqrt |
| L4 | 7 | fp_mult_pipeline, fp_adder_pipeline, fft_16pt_iterative, ifft_16pt_iterative, band_pass_fir, high_pass_fir, low_pass_fir |
| L5 | 6 | conv1d, conv2d, dct_idct_8pt_pipelined, harris_corner_detection, systolic_gemm, unsharp_mask |
| L6 | 8 | aes_decryption, aes_encryption, conv_3d, fft_streaming_64pt, fp_band_pass_fir, fp_high_pass_fir, fp_low_pass_fir, quantized_matmul |
| **Total** | **32** | |

---

## C2g Results (Multi-Turn CEGIS)

### Per-Design Solve Rate (at least 1/3 seeds solved)

| Level | gpt-5.5 | o4-mini | gpt-4o |
|-------|---------|---------|--------|
| L2 | **3/5** | **3/5** | 1/5 |
| L3 | **3/6** | 2/6 | 2/6 |
| L4 | **2/7** | **2/7** | 0/7 |
| L5 | **4/6** | 2/6 | 2/6 |
| L6 | **3/8** | 1/8 | 0/8 |
| **Total** | **15/32 (47%)** | **10/32 (31%)** | **5/32 (16%)** |

### Per-Seed Solve Rate (individual cells)

| Level | gpt-5.5 | o4-mini | gpt-4o |
|-------|---------|---------|--------|
| L2 | **7/15** | **7/15** | 3/15 |
| L3 | **9/18** | 5/18 | 2/18 |
| L4 | **6/21** | **6/21** | 0/21 |
| L5 | **12/18** | 4/18 | 2/18 |
| L6 | **9/24** | 1/24 | 0/24 |
| **Total** | **43/96 (44.8%)** | **23/96 (24.0%)** | **7/96 (7.3%)** |

---

## C2g Results — Per-Design Breakdown

### Level L2

| Design | gpt-5.5 | o4-mini | gpt-4o |
|--------|---------|---------|--------|
| aes128_single_round | **1/3** | **1/3** | 0/3 |
| cla_32bit_pipe | **3/3** | **3/3** | 0/3 |
| dadda_mult_pipe | 0/3 | 0/3 | 0/3 |
| rca_32bit_pipe | **3/3** | **3/3** | **3/3** |
| wallace_tree_mult_pipe | 0/3 | 0/3 | 0/3 |

### Level L3

| Design | gpt-5.5 | o4-mini | gpt-4o |
|--------|---------|---------|--------|
| fp_adder | **3/3** | 0/3 | 0/3 |
| fp_multiplier | **3/3** | 2/3 | 1/3 |
| gauss_siedel | 0/3 | 0/3 | 0/3 |
| gradient_descent | 0/3 | 0/3 | 0/3 |
| newton_raphson_polynomial | 0/3 | 0/3 | 0/3 |
| newton_raphson_sqrt | **3/3** | **3/3** | 1/3 |

### Level L4

| Design | gpt-5.5 | o4-mini | gpt-4o |
|--------|---------|---------|--------|
| fp_mult_pipeline | **3/3** | **3/3** | 0/3 |
| fp_adder_pipeline | **3/3** | **3/3** | 0/3 |
| fft_16pt_iterative | 0/3 | 0/3 | 0/3 |
| ifft_16pt_iterative | 0/3 | 0/3 | 0/3 |
| band_pass_fir | 0/3 | 0/3 | 0/3 |
| high_pass_fir | 0/3 | 0/3 | 0/3 |
| low_pass_fir | 0/3 | 0/3 | 0/3 |

### Level L5

| Design | gpt-5.5 | o4-mini | gpt-4o |
|--------|---------|---------|--------|
| conv1d | **3/3** | **3/3** | 1/3 |
| conv2d | **3/3** | 0/3 | 0/3 |
| dct_idct_8pt_pipelined | 0/3 | 0/3 | 0/3 |
| harris_corner_detection | **3/3** | 1/3 | 1/3 |
| systolic_gemm | 0/3 | 0/3 | 0/3 |
| unsharp_mask | **3/3** | 0/3 | 0/3 |

### Level L6

| Design | gpt-5.5 | o4-mini | gpt-4o |
|--------|---------|---------|--------|
| aes_decryption | **3/3** | 1/3 | 0/3 |
| aes_encryption | **3/3** | 0/3 | 0/3 |
| conv_3d | 0/3 | 0/3 | 0/3 |
| fft_streaming_64pt | **3/3** | 0/3 | 0/3 |
| fp_band_pass_fir | 0/3 | 0/3 | 0/3 |
| fp_high_pass_fir | 0/3 | 0/3 | 0/3 |
| fp_low_pass_fir | 0/3 | 0/3 | 0/3 |
| quantized_matmul | 0/3 | 0/3 | 0/3 |

---

## C1 Baseline Results (Zero-Shot Pass@5)

### Per-Seed Solve Rate

| Level | gpt-5.5 | o4-mini | gpt-4o |
|-------|---------|---------|--------|
| L2 | 3/15 | 2/15 | 3/15 |
| L3 | 0/18 | 2/18 | 0/18 |
| L4 | 6/21 | 0/21 | 0/21 |
| L5 | 3/18 | 3/18 | 1/18 |
| L6 | 4/24 | 0/24 | 0/24 |
| **Total** | **16/96 (16.7%)** | **7/96 (7.3%)** | **4/96 (4.2%)** |

### C1 Per-Design Breakdown

| Design | gpt-5.5 | o4-mini | gpt-4o |
|--------|---------|---------|--------|
| cla_32bit_pipe | **3/3** | 0/3 | 0/3 |
| rca_32bit_pipe | 0/3 | 2/3 | **3/3** |
| newton_raphson_sqrt | 0/3 | 2/3 | 0/3 |
| fp_mult_pipeline | **3/3** | 0/3 | 0/3 |
| fp_adder_pipeline | **3/3** | 0/3 | 0/3 |
| conv1d | **3/3** | **3/3** | 0/3 |
| harris_corner_detection | 0/3 | 0/3 | 1/3 |
| aes_decryption | 1/3 | 0/3 | 0/3 |
| aes_encryption | **3/3** | 0/3 | 0/3 |

---

## C2g vs C1 Comparison

### Per-Seed Solve Rate

| Model | C1 (zero-shot) | C2g (CEGIS) | Absolute Lift | Relative Lift |
|-------|----------------|-------------|---------------|---------------|
| gpt-5.5 | 16/96 (16.7%) | 43/96 (44.8%) | +27 seeds (+28.1pp) | +169% |
| o4-mini | 7/96 (7.3%) | 23/96 (24.0%) | +16 seeds (+16.7pp) | +229% |
| gpt-4o | 4/96 (4.2%) | 7/96 (7.3%) | +3 seeds (+3.1pp) | +75% |

### Per-Design Solve Rate

| Model | C1 designs | C2g designs | New designs from CEGIS |
|-------|-----------|-------------|----------------------|
| gpt-5.5 | 6/32 | 15/32 | +9: aes128_single_round, rca_32bit_pipe, fp_adder, fp_multiplier, newton_raphson_sqrt, conv2d, harris_corner_detection, unsharp_mask, fft_streaming_64pt |
| o4-mini | 3/32 | 10/32 | +7: cla_32bit_pipe, aes128_single_round, fp_mult_pipeline, fp_adder_pipeline, fp_multiplier, harris_corner_detection, aes_decryption |
| gpt-4o | 2/32 | 5/32 | +3: fp_multiplier, newton_raphson_sqrt, conv1d |

---

## Token Efficiency (C2g Solved Runs Only)

| Model | Solved Cells | Avg LLM Calls | Avg Wall (s) | Avg Input Tokens | Avg Output Tokens | Avg Total Tokens |
|-------|-------------|---------------|-------------|-----------------|-------------------|-----------------|
| gpt-4o | 7 | 6.6 | 129 | 22,967 | 5,300 | 28,267 |
| o4-mini | 23 | 9.7 | 370 | 89,271 | 58,082 | 147,353 |
| gpt-5.5 | 43 | 5.9 | 724 | 51,404 | 42,220 | 93,624 |

---

## Notable C2g Near-Misses (Best Score >90%)

| Design | Model | Best Score | Gap | Notes |
|--------|-------|-----------|-----|-------|
| conv2d | o4-mini | 4095/4096 | 1 test | Seeds 42 and 123 both at 4095/4096 |
| gauss_siedel | gpt-5.5 | 47/50 | 3 tests | All 3 seeds at 47/50 (94%) |
| newton_raphson_polynomial | gpt-5.5 | 97/100 | 3 tests | Seeds 42,456 at 97/100; o4-mini seed 42 also 97/100 |
| unsharp_mask | o4-mini | 64866/65536 | 670 tests | Seed 456 at 99.0%; all 3 seeds >98% |
| newton_raphson_sqrt | gpt-4o | 49/50 | 1 test | Seeds 42 and 456 both at 49/50 |
| fp_adder | o4-mini | 35/36 | 1 test | Seed 42 at 97.2% |
| fft_16pt_iterative | gpt-5.5 | 30/33 | 3 tests | Seed 123 at 90.9% |
| fp_mult_pipeline | gpt-4o | 27/30 | 3 tests | Seed 42 at 90.0% |
| band_pass_fir | gpt-4o | 801/1001 | 200 tests | Seeds 123,456 at 80-89% |

---

## Key Findings

1. **gpt-5.5 dominates across all levels**: 15/32 designs solved (47%), 43/96 seeds (44.8%). Uniquely solves fp_adder, conv2d, unsharp_mask, aes_encryption, fft_streaming_64pt (5 designs no other model solves). Perfect 3/3 seed consistency on 13 of 15 solved designs.

2. **o4-mini is strong second**: 10/32 designs (31%), 23/96 seeds (24.0%). Matches gpt-5.5 on L4 pipelined designs (fp_mult_pipeline, fp_adder_pipeline both 3/3) and L2 (cla_32bit_pipe, rca_32bit_pipe). Many tantalizing near-misses (conv2d 4095/4096, unsharp_mask 99.0%).

3. **gpt-4o is weakest**: 5/32 designs (16%), 7/96 seeds (7.3%). 0 solves at L4 or L6. But achieves interesting near-misses on FIR filters (band_pass_fir 80-89%) that other models don't.

4. **CEGIS feedback is critical**: All models show massive lifts from C1→C2g. gpt-5.5: 16/96→43/96 (+169%), o4-mini: 7/96→23/96 (+229%), gpt-4o: 4/96→7/96 (+75%). CEGIS unlocks 9 new designs for gpt-5.5, 7 for o4-mini, 3 for gpt-4o that zero-shot cannot solve.

5. **Universally unsolved**: dadda_mult_pipe, wallace_tree_mult_pipe (L2); gauss_siedel, gradient_descent, newton_raphson_polynomial (L3); fft/ifft_16pt, all FIR filters (L4); dct_idct_8pt_pipelined, systolic_gemm (L5); conv_3d, all fp_FIR variants, quantized_matmul (L6). Total: 17/32 designs unsolved by any model.

6. **gauss_siedel is the closest unsolved**: All 3 models achieve 88-94% pass rate (gpt-5.5 consistently at 47/50) but none break through. A promising target for more sophisticated methods.

---

## Experiment Timeline

- L5/L6 C2g (all 3 models): launched 2026-06-23 ~17:00 UTC, completed ~23:00 UTC
- L234 C2g (all 3 models): launched 2026-06-23 ~22:00 UTC
  - gpt-4o: completed 2026-06-23 23:54 UTC
  - o4-mini: completed 2026-06-24 00:05 UTC
  - gpt-5.5: completed 2026-06-24 05:28 UTC
- C1 baselines (all 3 models, L2-L6): launched 2026-06-24 04:00 UTC
  - gpt-4o: completed 2026-06-24 ~05:00 UTC (4/96 solved)
  - o4-mini: completed 2026-06-24 ~05:54 UTC (7/96 solved)
  - gpt-5.5: completed 2026-06-24 ~08:38 UTC (16/96 solved)

---

*Document updated: 2026-06-24T08:40Z. All experiments complete.*
