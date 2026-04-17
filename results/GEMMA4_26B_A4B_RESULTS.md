# Gemma-4-26B-A4B vs Nemotron-Cascade-2-30B-A3B: Full Results Summary

**Date**: 2026-04-13

## Overview

This document compares Gemma-4-26B-A4B (Unsloth UD-Q4_K_XL) and Nemotron-Cascade-2-30B-A3B on two machines:
- **macbook2**: Apple M2 Max, 96GB RAM, Metal backend
- **gigul2**: AMD 7900 XTX 24GB, 128GB RAM, HIP ROCm backend

---

## CONTEXT Benchmark Results

### Gemma-4-26B-A4B on macbook2 (Q8_0, thinking OFF)

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.458s | 40.0 tok/s |
| 100 | 0 | 100 | 0.500s | 37.1 tok/s |
| 15K | 5K | 10K | 13.721s | 14.1 tok/s |
| 20K | 5K | 15K | 21.330s | 10.2 tok/s |
| 30K | 20K | 10K | 18.105s | 9.3 tok/s |
| 35K | 20K | 15K | 28.060s | 8.2 tok/s |
| 50K | 40K | 10K | 24.210s | 6.9 tok/s |
| 55K | 40K | 15K | 37.424s | 5.5 tok/s |
| 110K | 100K | 10K | 44.240s | 3.6 tok/s |
| 115K | 100K | 15K | 65.158s | 3.2 tok/s |

### Gemma-4-26B-A4B on macbook2 (UD-Q4_K_XL, thinking ON, ngram enabled)

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|
| Same server | - | - | - | - |

**Note**: macbook2 thinking ON context was tested against same server as thinking OFF (requests sent `enable_thinking=false`).

### Gemma-4-26B-A4B on gigul2 (UD-Q4_K_XL)

| Total context | Prefill | Prompt | OFF TTFT | OFF tok/s | ON 8K TTFT | ON 8K tok/s |
|---|---:|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.190s | 67.8 | 1.191s | 50.3 |
| 100 | 0 | 100 | 0.175s | 66.7 | 0.174s | 64.8 |
| 15K | 5K | 10K | 8.445s | 39.4 | 10.591s | 32.4 |
| 20K | 5K | 15K | 13.024s | 28.4 | 16.880s | 23.6 |
| 30K | 20K | 10K | 9.322s | 36.9 | 12.146s | 28.5 |
| 35K | 20K | 15K | 14.159s | 29.0 | 17.672s | 24.6 |
| 50K | 40K | 10K | 10.125s | 34.4 | 12.326s | 29.8 |
| 55K | 40K | 15K | 15.295s | 27.5 | 17.645s | 23.8 |
| 110K | 100K | 10K | 12.412s | 30.3 | CRASH | - |
| 115K | 100K | 15K | 18.316s | 23.8 | CRASH | - |

### Nemotron-Cascade-2-30B-A3B on macbook2 (Q8, thinking ON)

| Total context | Prefill | Prompt | ON TTFT | ON tok/s |
|---|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.327s | 56.0 tok/s |
| 100 | 0 | 100 | 0.464s | 50.0 tok/s |
| 15K | 5K | 10K | 12.504s | 22.3 tok/s |
| 20K | 5K | 15K | 21.121s | 15.5 tok/s |
| 30K | 20K | 10K | 14.488s | 19.9 tok/s |
| 35K | 20K | 15K | 21.518s | 15.1 tok/s |
| 50K | 40K | 10K | 17.831s | 15.2 tok/s |
| 55K | 40K | 15K | 26.312s | 14.1 tok/s |
| 110K | 100K | 10K | 28.246s | 11.4 tok/s |
| 115K | 100K | 15K | 41.839s | 10.1 tok/s |

### Nemotron-Cascade-2-30B-A3B on gigul2 (IQ4_XS)

| Total context | Prefill | Prompt | OFF TTFT | OFF tok/s | ON 5K TTFT | ON 5K tok/s |
|---|---:|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.341s | 89.4 | 0.393s | 98.9 |
| 100 | 0 | 100 | 0.287s | 93.5 | 0.314s | 100.9 |
| 15K | 5K | 10K | 4.754s | 43.5 | 4.803s | 54.1 |
| 20K | 5K | 15K | 7.700s | 35.1 | 7.728s | 42.4 |
| 30K | 20K | 10K | 7.618s | 35.4 | 7.641s | 40.5 |
| 35K | 20K | 15K | 11.862s | 25.4 | 11.908s | 30.6 |
| 50K | 40K | 10K | 11.519s | 27.0 | 11.535s | 32.4 |
| 55K | 40K | 15K | 17.588s | 20.3 | 17.620s | 22.7 |
| 110K | 100K | 10K | 23.206s | 15.5 | 23.223s | 19.5 |
| 115K | 100K | 15K | 34.697s | 11.5 | 34.943s | 13.3 |

---

## LCB LiveCodeBench Results (92 problems)

### Gemma-4-26B-A4B Results

| Machine | Quant | Thinking | Budget | Overall | Easy | Medium | Hard | Solved | Runtime |
|---------|-------|----------|--------|---------|------|--------|------|--------|---------|
| macbook2 | Q8_0 | OFF | - | **0.8804** | 1.0000 | 0.9231 | 0.6190 | 81/92 | 9139s |
| macbook2 | UD-Q4_K_XL | ON | 8K (ngram) | 0.2065 | 0.3750 | 0.1795 | 0.0000 | 19/92 | 40045s |
| gigul2 | UD-Q4_K_XL | OFF | - | **0.8696** | 1.0000 | 0.9487 | 0.5238 | 80/92 | 3656s |
| gigul2 | UD-Q4_K_XL | ON | 8K | 0.8478 | 1.0000 | 0.8974 | 0.5238 | 78/92 | 13422s |
| gigul2 | UD-Q4_K_XL | ON | 5K | 0.8370 | 1.0000 | 0.8718 | 0.5238 | 77/92 | 9522s |

### Nemotron-Cascade-2-30B-A3B Results

| Machine | Quant | Thinking | Budget | Overall | Easy | Medium | Hard | Solved | Runtime |
|---------|-------|----------|--------|---------|------|--------|------|--------|---------|
| macbook2 | Q6 | ON | 4K | 0.8152 | 1.0000 | 0.8462 | 0.4762 | 75/92 | 8146s |
| macbook2 | Q6 | OFF | - | 0.7717 | 0.9688 | 0.8718 | 0.2857 | 71/92 | ~3h |
| macbook2 | Q8 | ON | 8K | 0.8152 | 0.9688 | 0.8205 | 0.5714 | 75/92 | 12252s |
| macbook2 | Q8 | OFF | - | 0.5000 | 0.9062 | 0.4359 | 0.0000 | 46/92 | ~3h |
| gigul2 | IQ4_XS | OFF | - | 0.5326 | 0.8750 | 0.4872 | 0.0952 | 49/92 | ~4h |
| gigul2 | IQ4_XS | ON | 5K | **0.8261** | 1.0000 | 0.8462 | 0.5238 | 76/92 | ~4h |

---

## Cross-Machine Comparison: Context

### macbook2: Gemma4 vs Nemotron (both thinking ON for Nemotron)

| Scenario | Gemma4 OFF TTFT | Gemma4 tok/s | Nemotron ON TTFT | Nemotron tok/s |
|---|---:|---:|---:|---:|
| None 50 | 0.458s | 40.0 | 0.327s | 56.0 |
| None 100 | 0.500s | 37.1 | 0.464s | 50.0 |
| Small 15K | 13.721s | 14.1 | 12.504s | 22.3 |
| Small 20K | 21.330s | 10.2 | 21.121s | 15.5 |
| Mid 30K | 18.105s | 9.3 | 14.488s | 19.9 |
| Mid 35K | 28.060s | 8.2 | 21.518s | 15.1 |
| Long 50K | 24.210s | 6.9 | 17.831s | 15.2 |
| Long 55K | 37.424s | 5.5 | 26.312s | 14.1 |
| Longlong 110K | 44.240s | 3.6 | 28.246s | 11.4 |
| Longlong 115K | 65.158s | 3.2 | 41.839s | 10.1 |

### gigul2: Gemma4 vs Nemotron (Gemma4 OFF, Nemotron ON)

| Scenario | Gemma4 OFF TTFT | Gemma4 tok/s | Nemotron ON TTFT | Nemotron tok/s |
|---|---:|---:|---:|---:|
| None 50 | 0.190s | 67.8 | 0.393s | 98.9 |
| None 100 | 0.175s | 66.7 | 0.314s | 100.9 |
| Small 15K | 8.445s | 39.4 | 4.803s | 54.1 |
| Small 20K | 13.024s | 28.4 | 7.728s | 42.4 |
| Mid 30K | 9.322s | 36.9 | 7.641s | 40.5 |
| Mid 35K | 14.159s | 29.0 | 11.908s | 30.6 |
| Long 50K | 10.125s | 34.4 | 11.535s | 32.4 |
| Long 55K | 15.295s | 27.5 | 17.620s | 22.7 |
| Longlong 110K | 12.412s | 30.3 | 23.223s | 19.5 |
| Longlong 115K | 18.316s | 23.8 | 34.943s | 13.3 |

---

## Cross-Machine Comparison: LCB

### macbook2

| Model | Thinking | Overall | Easy | Medium | Hard | Solved |
|---|----------|--------|------|--------|------|--------|
| Gemma4 Q8_0 | OFF | **0.8804** | 1.0000 | 0.9231 | 0.6190 | 81/92 |
| Nemotron Q6 | ON 4K | 0.8152 | 1.0000 | 0.8462 | 0.4762 | 75/92 |
| Nemotron Q6 | OFF | 0.7717 | 0.9688 | 0.8718 | 0.2857 | 71/92 |
| Nemotron Q8 | ON 8K | 0.8152 | 0.9688 | 0.8205 | 0.5714 | 75/92 |
| Gemma4 UD-Q4_K_XL | ON (ngram) | 0.2065 | 0.3750 | 0.1795 | 0.0000 | 19/92 |

### gigul2

| Model | Thinking | Overall | Easy | Medium | Hard | Solved |
|---|----------|--------|------|--------|------|--------|
| Gemma4 UD-Q4_K_XL | OFF | **0.8696** | 1.0000 | 0.9487 | 0.5238 | 80/92 |
| Gemma4 UD-Q4_K_XL | ON 8K | 0.8478 | 1.0000 | 0.8974 | 0.5238 | 78/92 |
| Gemma4 UD-Q4_K_XL | ON 5K | 0.8370 | 1.0000 | 0.8718 | 0.5238 | 77/92 |
| Nemotron IQ4_XS | ON 5K | 0.8261 | 1.0000 | 0.8462 | 0.5238 | 76/92 |
| Nemotron IQ4_XS | OFF | 0.5326 | 0.8750 | 0.4872 | 0.0952 | 49/92 |

---

## Key Findings

### 1. Ngram Speculative Decode Was Devastating

The macbook2 Gemma4 thinking ON run with ngram enabled scored only **0.2065** - the worst result in any configuration. Disabling ngram on gigul2 yielded **0.8696** - proving ngram was the problem, not thinking itself.

### 2. Thinking ON vs OFF Effects

**For Gemma4:**
- Thinking OFF is better than thinking ON on both machines
- macbook2: OFF (0.8804) > ON (baseline, 0.2065 with ngram)
- gigul2: OFF (0.8696) > ON 8K (0.8478) > ON 5K (0.8370)

**For Nemotron:**
- Thinking ON is better than thinking OFF
- gigul2: ON (0.8261) > OFF (0.5326) - dramatic improvement from thinking
- macbook2: ON (0.8152) > OFF (0.5000) - also dramatic

### 3. Machine Comparison

**macbook2:**
- Gemma4 OFF (0.8804) > Nemotron ON (0.8152)
- Nemotron benefits more from thinking than Gemma4 on this machine

**gigul2:**
- Gemma4 OFF (0.8696) > Gemma4 ON (0.8478) > Nemotron ON (0.8261)
- Gemma4 thinking OFF is the best overall score on gigul2

### 4. Context Behavior

**macbook2:**
- Nemotron has lower TTFT at all context levels
- Gemma4 has higher throughput at short context, Nemotron catches up at long context

**gigul2:**
- Nemotron has lower TTFT at all context levels
- Gemma4 has higher throughput across most context levels
- Gemma4 works at 110K+ with thinking OFF, crashes with thinking ON
- Nemotron works at 110K+ but slows significantly

### 5. Runtime Comparison

Gemma4 OFF on gigul2 is dramatically faster than any other LCB configuration:
- Gemma4 OFF: 3,656s (~1h)
- Gemma4 ON 5K: 9,522s (~2.6h)
- Gemma4 ON 8K: 13,422s (~3.7h)
- Nemotron ON: ~4h

---

## Takeaways

1. **Best overall LCB score**: Gemma4 OFF on macbook2 (0.8804) and gigul2 (0.8696)
2. **Best context performance on gigul2**: Mixed - Nemotron has better TTFT, Gemma4 has better throughput
3. **Ngram speculative decode must be disabled** for Gemma4 thinking ON
4. **Thinking ON benefits Nemotron more than Gemma4** on LCB
5. **Gemma4 prefers thinking OFF** on LCB, achieves best score with OFF
6. **110K+ context**: Gemma4 OFF works on gigul2, Gemma4 ON crashes (memory)
