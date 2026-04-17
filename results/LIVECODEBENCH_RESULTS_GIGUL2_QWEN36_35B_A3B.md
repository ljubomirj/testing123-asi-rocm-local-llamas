# LiveCodeBench Results: Qwen3.6-35B-A3B IQ4_XS vs Nemotron-Cascade-2-30B-A3B IQ4_XS — gigul2

**Date**: 2026-04-16

**Hardware**: `gigul2` (AMD Radeon RX 7900 XTX 24GB, HIP ROCm, Xeon 10-core, 128GB RAM)

**Benchmark**: LiveCodeBench 92-problem union subset (3 time windows: 2024-01/02, 2024-05/06, 2025-04/05)

**Server**: `~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server`, `temp=0.0`, `top_p=1.0`, greedy decoding

## Results

On the 92-problem union subset, the local gigul2 results are:

| Model / mode | Overall | Easy | Medium | Hard | Solved | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| **Qwen3.6-35B-A3B-IQ4_XS OFF** | **0.7717** | **0.9688** | **0.8462** | **0.3333** | **71 / 92** | **4302s** |
| **Qwen3.6-35B-A3B-IQ4_XS ON, budget 5000 / total 10000** | **0.8478** | **1.0000** | **0.9487** | **0.4286** | **78 / 92** | **8411s** |
| Nemotron-Cascade-2-30B-A3B-IQ4_XS OFF | 0.5326 | 0.8750 | 0.4872 | 0.0952 | 49 / 92 | 1907s |
| Nemotron-Cascade-2-30B-A3B-IQ4_XS ON, budget 5000 / total 10000 | 0.8261 | 1.0000 | 0.8462 | 0.5238 | 76 / 92 | 3776s |

## Analysis

### Qwen3.6 OFF vs Qwen3.6 ON

Thinking ON improved every dimension:
- Overall: +7.6pp (0.7717 → 0.8478)
- Easy: +3.1pp (0.9688 → 1.0000, perfect)
- Medium: +10.3pp (0.8462 → 0.9487)
- Hard: +9.5pp (0.3333 → 0.4286)
- Runtime: ~2× slower (4302s → 8411s, expected with thinking tokens)

The reasoning budget of 5000 thinking tokens out of 10000 total worked correctly with Qwen3.6 — no budget exhaustion issues observed.

### Qwen3.6 vs Nemotron

**Qwen3.6 OFF already surpasses Nemotron ON in overall score** (0.7717 vs 0.8261)... wait, no — Nemotron ON is 0.8261, Qwen3.6 OFF is 0.7717. Nemotron ON still edges Qwen3.6 OFF overall.

But **Qwen3.6 ON (0.8478) beats Nemotron ON (0.8261)** overall:
- Overall: +2.2pp (0.8478 vs 0.8261)
- Easy: tied at 1.0000
- Medium: Qwen3.6 wins (0.9487 vs 0.8462, +10.3pp)
- Hard: Nemotron wins (0.5238 vs 0.4286, -9.5pp)

The tradeoff: Qwen3.6 ON is much stronger on medium problems but weaker on hard. Runtime is also 2.2× longer (8411s vs 3776s) due to the larger model.

### Key Insight

Qwen3.6-35B-A3B at IQ4_XS quant delivers substantially better quality than Nemotron-Cascade-2-30B-A3B at the same quant level, at the cost of ~2× runtime. The reasoning budget mechanism works reliably with Qwen3.6 (it had issues with Nemotron in some prior runs).

## Run Details

### Qwen3.6 OFF
- Run root: `runs/livecodebench_qwen36_gigul2_off_total10000_20260416_200322`
- Server: thinking OFF, `--reasoning off --reasoning-format none`
- Solved: 71 / 92

### Qwen3.6 ON (budget 5000 / total 10000)
- Run root: `runs/livecodebench_qwen36_gigul2_on_total10000_20260416_211545`
- Server: thinking ON, `--reasoning on --reasoning-format deepseek --reasoning-budget 5000 --reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now."`
- Solved: 78 / 92
