# Context Benchmark Results - GLM-4.7-Flash MLX-8bit on macbook2

**Date**: 2026-02-17
**Model**: GLM-4.7-Flash (zai-org/glm-4.7-flash), MLX 8-bit quantization
**Hardware**: Apple M2 Max, 96GB unified memory, ~400 GB/s bandwidth
**Model size on disk**: 31.84 GB
**Architecture**: glm4_moe_lite (MoE: 64 experts, 4 active per token, 47 layers)
**Max position embeddings**: 202,752 (model config)
**Comparison**: vs gigul2 (AMD 7900 XTX 24GB, llama.cpp HIP ROCm 7.1.1 Q4)

Two backends tested:
1. **LM Studio MLX** (localhost:1234) - Flash Attention enabled, context-length 32768
2. **vLLM-MLX 0.2.6** (localhost:8082) - mlx 0.30.6, mlx-lm 0.30.7, timeout 1800s

---

## Summary Table

| Tier | Total Context | LM Studio MLX | vLLM-MLX | gigul2 HIP ROCm Q4 |
|------|--------------|---------------|----------|---------------------|
| **none** | 10K | 31.3s / 10.2 tok/s | 30.2s / 11.7 tok/s | 0.4s / 88 tok/s |
| **none** | 15K | 66.0s / 5.9 tok/s (intermittent crash) | 43.5s / 8.9 tok/s | - |
| **small** | 20K | CRASH | 63.5s / 7.1 tok/s | 8.9s / 39.6 tok/s |
| **small** | 25K | CRASH | 91.4s / 5.9 tok/s | 14.9s / 29.2 tok/s |
| **mid** | 50K | CRASH | 225.4s / 2.7 tok/s | 20.6s / 21.8 tok/s |
| **mid** | 55K | CRASH | 217.0s / 2.7 tok/s | 32.5s / 16.2 tok/s |
| **large** | 90K | CRASH | Server OOM/crash | 44.0s / 11.2 tok/s |
| **largelarge** | 138K | CRASH | Server OOM/crash | 67.3s / 7.9 tok/s |

Format: TTFT / Throughput. gigul2 values from HIP ROCm 7.1.1 Q4 benchmarks.

---

## Backend 1: LM Studio MLX

### Critical Finding: MLX Context Limit Bug

**LM Studio's MLX backend crashes at ~15K-17K tokens** with:
```
AttributeError: 'list' object has no attribute 'swapaxes'
```
or silently: `"The model has crashed without additional information. (Exit code: null)"`

This is a bug in LM Studio's MLX implementation of `glm4_moe_lite`, not a memory limitation. Only the "none-context" tier could be benchmarked.

### Results: 10K Total Context (0 prefill + 10K prompt)

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 29.781 | 8.9 | 380 tok | 42.6 |
| 2 | 32.481 | 10.6 | 607 tok | 57.1 |
| 3 | 31.494 | 11.1 | 578 tok | 52.0 |
| **Avg** | **31.3** | **10.2** | **522** | **50.5** |

### Results: 15K Total Context (0 prefill + 15K prompt)

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 70.544 | 5.4 | 479 tok | 89.1 |
| 2 | 64.963 | 6.1 | 512 tok | 83.9 |
| 3 | 62.432 | 6.1 | 485 tok | 79.1 |
| **Avg** | **66.0** | **5.9** | **492** | **84.0** |

Note: 15K worked in session A (old streaming parser) but crashed consistently in session B. The crash threshold is non-deterministic near the boundary.

### Crash Recovery

Implemented auto-reload via `lms` CLI:
```bash
lms unload --all
lms load "zai-org/glm-4.7-flash" --gpu max --context-length 32768 --identifier "zai-org/glm-4.7-flash" -y
```

---

## Backend 2: vLLM-MLX 0.2.6

vLLM-MLX uses a different MLX implementation (mlx-lm 0.30.7) and does NOT hit the `swapaxes` crash. Contexts up to ~55K work reliably.

### None-Context (0 prefill)

**10K Total Context:**

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 31.555 | 11.2 | 614 tok | 55.0 |
| 2 | 29.208 | 11.6 | 603 tok | 52.2 |
| 3 | 29.686 | 12.3 | 618 tok | 50.1 |
| **Avg** | **30.2** | **11.7** | **612** | **52.4** |

**15K Total Context:**

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 47.282 | 8.6 | 593 tok | 68.7 |
| 2 | 41.428 | 8.8 | 537 tok | 61.3 |
| 3 | 41.748 | 9.4 | 576 tok | 61.6 |
| **Avg** | **43.5** | **8.9** | **569** | **63.9** |

### Small-Context (10K prefill)

**20K Total Context:**

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 57.307 | 7.2 | 588 tok | 81.2 |
| 2 | 67.216 | 6.6 | 612 tok | 92.8 |
| 3 | 65.881 | 7.6 | 697 tok | 92.2 |
| **Avg** | **63.5** | **7.1** | **632** | **88.7** |

**25K Total Context:**

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 98.114 | 5.4 | 685 tok | 126.1 |
| 2 | 94.434 | 5.7 | 692 tok | 120.8 |
| 3 | 81.636 | 6.5 | 687 tok | 105.2 |
| **Avg** | **91.4** | **5.9** | **688** | **117.4** |

### Mid-Context (40K prefill)

**50K Total Context:**

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 223.781 | 2.6 | 663 tok | 259.6 |
| 2 | 262.918 | 2.3 | 692 tok | 295.1 |
| 3 | 189.605 | 3.1 | 694 tok | 220.7 |
| **Avg** | **225.4** | **2.7** | **683** | **258.5** |

**55K Total Context:**

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 214.878 | 2.7 | 667 tok | 247.5 |
| 2 | 221.445 | 2.7 | 695 tok | 253.7 |
| 3 | 214.780 | 2.8 | 682 tok | 246.4 |
| **Avg** | **217.0** | **2.7** | **681** | **249.2** |

### Large-Context (80K prefill) - FAILED

The 80K prefill request (320K chars) caused the vLLM-MLX server to crash/OOM after ~370s. Server process died silently. The same would apply to largelarge (128K prefill).

---

## Comparison: vLLM-MLX vs gigul2 HIP ROCm Q4

| Context | macbook2 vLLM-MLX TTFT | gigul2 HIP TTFT | Ratio | macbook2 tok/s | gigul2 tok/s | Ratio |
|---------|----------------------|-----------------|-------|----------------|--------------|-------|
| 10K | 30.2s | 0.4s | 76x | 11.7 | 88 | 7.5x |
| 20K | 63.5s | 8.9s | 7.1x | 7.1 | 39.6 | 5.6x |
| 25K | 91.4s | 14.9s | 6.1x | 5.9 | 29.2 | 4.9x |
| 50K | 225.4s | 20.6s | 10.9x | 2.7 | 21.8 | 8.1x |
| 55K | 217.0s | 32.5s | 6.7x | 2.7 | 16.2 | 6.0x |
| 90K | OOM/crash | 44.0s | - | - | 11.2 | - |

### Key Observations

1. **TTFT gap is enormous**: 6-11x slower at matched context sizes (vs 2.4x memory bandwidth ratio). The MLX backend on this model is extremely inefficient for prefill.

2. **Throughput gap**: 5-8x slower, also worse than the bandwidth ratio. The 8-bit quantization (vs Q4) partially explains this (2x more data to read), but not fully.

3. **Context scaling**: macbook2 TTFT scales roughly O(n^2), going from 30s at 10K to 225s at 50K (7.5x for 5x context). gigul2 scales much better: 0.4s to 20.6s (51x but from a much lower base).

4. **vLLM-MLX vs LM Studio**: vLLM-MLX is clearly superior on this model:
   - Doesn't crash at 15K-17K tokens (works up to ~55K)
   - Similar performance at 10K (30.2s vs 31.3s TTFT, 11.7 vs 10.2 tok/s)
   - 15K: 43.5s vs 66.0s TTFT (34% faster, and doesn't crash)

5. **Practical limits**: 50-55K context is usable but slow (~4 min TTFT, 2.7 tok/s). 80K+ is beyond MLX-8bit capacity on 96GB M2 Max.

---

## Hardware Details

### macbook2 (this test)
- **CPU**: Apple M2 Max (38-core GPU)
- **RAM**: 96GB unified memory
- **Memory Bandwidth**: ~400 GB/s
- **OS**: macOS 15.7.3 (arm64)
- **Model**: `lmstudio-community/GLM-4.7-Flash-MLX-8bit` (31.84 GB)

### gigul2 (comparison)
- **GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
- **RAM**: 128GB system
- **Memory Bandwidth**: 960 GB/s (GPU)
- **Backend**: llama.cpp HIP ROCm 7.1.1 (Q4 quantization)

---

## Reproduction

```bash
# LM Studio MLX backend
lms load "zai-org/glm-4.7-flash" --gpu max --context-length 32768 \
  --identifier "zai-org/glm-4.7-flash" -y

python3 bench_longcontext_macbook.py \
  --base http://localhost:1234 --model "zai-org/glm-4.7-flash" \
  --no-prefill --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "lmstudio-mlx-8bit"

# vLLM-MLX backend
/path/to/vllm-mlx/.venv/bin/vllm-mlx serve \
  /path/to/GLM-4.7-Flash-MLX-8bit \
  --port 8082 --max-tokens 512 --timeout 1800

python3 bench_longcontext_macbook.py \
  --base http://localhost:8082 --model "<model-path>" \
  --prefill-tokens 40000 --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "vllm-mlx-8bit"
```

## Files

- `benchmark_macbook2_lmstudio_mlx8bit_glm47_nonecontext_results.jsonl` - LM Studio none-context
- `benchmark_macbook2_lmstudio_glm47_nonecontext_results.jsonl` - LM Studio none-context (session A)
- `benchmark_macbook2_vllm-mlx_8bit_glm47_nonecontext_results.jsonl` - vLLM-MLX none-context
- `benchmark_macbook2_vllm-mlx_8bit_glm47_smallcontext_results.jsonl` - vLLM-MLX small-context
- `benchmark_macbook2_vllm-mlx_8bit_glm47_midcontext_results.jsonl` - vLLM-MLX mid-context
- `benchmark_macbook2_vllm-mlx_8bit_glm47_largecontext_results.jsonl` - vLLM-MLX large-context (crash)
- `bench_longcontext_macbook.py` - Benchmark script with crash detection + lms auto-reload
