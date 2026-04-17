# Qwen3.6-35B-A3B vs Nemotron-Cascade-2-30B-A3B Comparison

**Date**: 2026-04-17

**Purpose**: Compare new default (Qwen3.6-35B-A3B) vs old default (Nemotron-Cascade-2-30B-A3B) on same platform/config.

---

## Summary

| Metric | Qwen3.6-35B-A3B | Nemotron-Cascade-2-30B-A3B | Winner |
|---|---|---|---|
| **Parameters** | 35B | 30B | Qwen (larger) |
| **Accuracy (LCB)** | 83-85% pass@1 | 81-83% pass@1 | **Qwen** |
| **Speed (macbook2)** | Slower | Faster | Nemotron |
| **Speed (7900 XTX)** | Similar | Similar | Tie |

---

## macbook2 (M2 Max, 96GB, Metal)

### CONTEXT Test - Thinking ON (tok/s throughput)

| Context | Qwen3.6 Q6_K_XL | Nemotron Q6 | Delta |
|---|---:|---:|---:|
| 50 | 44.4 | 57.7 | +30% Nemotron |
| 100 | 40.8 | 52.4 | +28% Nemotron |
| 15K | 20.3 | 23.3 | +15% Nemotron |
| 30K | 18.6 | 21.4 | +15% Nemotron |
| 50K | 13.5 | 16.4 | +21% Nemotron |
| 110K | 0.6 | 10.6 | +1667% Nemotron |

**Winner**: **Nemotron** 15-30% faster on throughput.

### LCB Test - Thinking ON (accuracy & runtime)

| Model | Quant | Overall | Easy | Medium | Hard | Runtime |
|---|---|---:|---:|---:|---:|---:|
| **Qwen3.6-35B-A3B** | Q6_K_XL | **83.70%** | 100% | 89.7% | 47.6% | 7.4h |
| Nemotron-Cascade-2-30B-A3B | Q6 | 81.52% | 100% | 84.6% | 47.6% | 2.3h |

**Winner**: **Qwen** +2.2pp pass@1, but takes 3.2× longer.

**Note**: Different reasoning budgets (Qwen: 5000, Nemotron: 4096). Both use deepseek format.

### LCB Test - Thinking OFF vs ON (macbook2)

| Model | Mode | Overall | Easy | Medium | Hard | Runtime |
|---|---|---:|---:|---:|---:|---:|
| Nemotron Q6 | OFF | 50.00% | 90.6% | 43.6% | 0% | 0.4h |
| Nemotron Q6 | ON | 81.52% | 100% | 84.6% | 47.6% | 2.3h |

**Winner**: Thinking ON is essential for Nemotron (+31.5pp pass@1).

---

## gigul2 (7900 XTX 24GB, HIP ROCm)

### CONTEXT Test - Thinking ON (tok/s throughput)

| Context | Qwen3.6 IQ4_XS | Nemotron IQ4_XS | Delta |
|---|---:|---:|---:|
| 50 | 61.0 | 98.9 | +62% Nemotron |
| 100 | 59.9 | 100.9 | +68% Nemotron |
| 15K | 40.4 | 54.1 | +34% Nemotron |
| 30K | 34.9 | 40.5 | +16% Nemotron |
| 50K | 25.4 | 32.4 | +28% Nemotron |
| 110K | 15.1 | 19.5 | +29% Nemotron |

**Winner**: **Nemotron** 16-68% faster on throughput.

### LCB Test - Thinking ON (accuracy & runtime)

| Model | Quant | Overall | Easy | Medium | Hard | Runtime |
|---|---||---:|---:|---:|---:|
| **Qwen3.6-35B-A3B** | IQ4_XS | **84.78%** | 100% | 94.9% | 42.9% | 2.3h |
| Nemotron-Cascade-2-30B-A3B | IQ4_XS | 82.61% | 100% | 84.6% | 52.4% | 1.0h |

**Winner**: **Qwen** +2.2pp pass@1, but takes 2.3× longer.

### LCB Test - Thinking OFF vs ON (gigul2)

| Model | Mode | Overall | Easy | Medium | Hard | Runtime |
|---|---|---:|---:|---:|---:|---:|
| Qwen3.6 IQ4_XS | OFF | 77.17% | 96.9% | 84.6% | 33.3% | 1.2h |
| Qwen3.6 IQ4_XS | ON | 84.78% | 100% | 94.9% | 42.9% | 2.3h |
| Nemotron IQ4_XS | ON | 82.61% | 100% | 84.6% | 52.4% | 1.0h |

**Winner**: Qwen ON for best overall accuracy. Nemorton ON for best hard problems.

---

## Cross-Platform Comparison

### Qwen3.6-35B-A3B: macbook2 vs gigul2

| Context | macbook2 Q6_K_XL | gigul2 IQ4_XS | Ratio |
|---|---:|---:|---:|
| 50 | 44.4 | 61.0 | 1.4× gigul2 |
| 100 | 40.8 | 59.9 | 1.5× gigul2 |
| 15K | 20.3 | 40.4 | 2.0× gigul2 |
| 30K | 18.6 | 34.9 | 1.9× gigul2 |
| 50K | 13.5 | 25.4 | 1.9× gigul2 |

7900 XTX is 1.4-2× faster on throughput.

---

## Key Takeaways

### Speed
1. **Nemotron is 15-68% faster** on tok/s throughput at same context size
2. **Qwen is 2-3× slower** on LCB runtime (larger model + more thinking)

### Accuracy
1. **Qwen wins on LCB**: +2.2pp pass@1 overall
2. **Qwen stronger on Medium**: Qwen 89-95% vs Nemotron 85-87%
3. **Nemorton stronger on Hard (gigul2)**: Nemotron 52% vs Qwen 43%

### Tradeoffs
| Consideration | Choose Qwen3.6 | Choose Nemotron |
|---|---|---|
| Best overall accuracy | ✅ | |
| Best medium problem accuracy | ✅ | |
| Best hard problem accuracy | | ✅ (gigul2) |
| Fastest inference | | ✅ |
| Lowest memory | | ✅ (30B vs 35B) |

### Recommendation
- **Default to Qwen3.6-35B-A3B** for best overall accuracy
- **Consider Nemorton** for:
  - Faster inference required
  - Hard problem focus (gigul2)
  - Memory-constrained environments

---

## Test Configurations

### Qwen3.6-35B-A3B (both platforms)
```bash
--reasoning on --reasoning-format deepseek --reasoning-budget 5000
--chat-template-kwargs '{"enable_thinking":true}'
--jinja
```

### Nemotron-Cascade-2-30B-A3B (both platforms)
```bash
--reasoning on --reasoning-format deepseek --reasoning-budget 4096
--chat-template-kwargs '{"enable_thinking":true}'
--jinja
```

---

## Source Files

**Qwen3.6-35B-A3B:**
- `CONTEXT_RESULTS_QWEN36_35B_A3B_MACBOOK2.md`
- `LCB_RESULTS_QWEN36_35B_A3B_MACBOOK2.md`
- `CONTEXT_RESULTS_GIGUL2_LLAMACPP_HIP_ROCWMMA_QWEN36_35B_A3B.md`
- `LIVECODEBENCH_RESULTS_GIGUL2_QWEN36_35B_A3B.md`

**Nemotron-Cascade-2-30B-A3B:**
- `CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_NEMOTRON_CASCADE_2_30B_A3B.md`
- `LIVECODEBENCH_MACBOOK2_QWEN35_VS_NEMOTRON_VARIANTS.md`
- `CONTEXT_RESULTS_GIGUL2_LLAMACPP_HIP_ROCWMMA_NEMOTRON_CASCADE_2_30B_A3B.md`
- `LIVECODEBENCH_GIGUL2_QWEN35_VS_NEMOTRON_IQ4XS.md`
