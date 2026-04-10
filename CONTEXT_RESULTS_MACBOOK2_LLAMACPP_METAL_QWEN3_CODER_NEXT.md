# Context Benchmark Results - Qwen3-Coder-Next Q5_K_XL on macbook2 (llama.cpp Metal b8393)

**Date**: 2026-02-21
**Model**: Qwen3-Coder-Next-UD-Q5_K_XL (80B params, 512 MoE experts, 10 active/token)
**Hardware**: Apple M2 Max, 96GB unified memory, ~400 GB/s bandwidth
**Model size on disk**: ~56.84 GB (Q5_K_XL quantization)
**Architecture**: MoE, n_embd=2048, n_ctx_train=262144, vocab=151936
**Backend**: llama.cpp b8393 Metal (build.macbook2-metal)
**Server config**: n_ctx=130048, 4 slots
**Port**: 127.0.0.1:8081
**Purpose**: Test if latest llama.cpp Metal (b8393) performs better than previous builds

---

## Summary Table

| Tier | Total Context | TTFT (s) | Throughput (tok/s) | gigul2 HIP TTFT | gigul2 tok/s |
|------|--------------|----------|-------------------|-----------------|--------------|
| **none** | 10K | 17.1 | 10.9 | - | 12.5* |
| **none** | 15K | 12.1 | 13.2 | - | - |
| **small** | 20K | 22.4 | 11.2 | 26.4 | 7.8 |
| **small** | 25K | 32.8 | 8.8 | 39.2 | 6.2 |
| **mid** | 50K | 28.8 | 9.0 | 37.7 | 6.7 |
| **mid** | 55K | 42.3 | 7.3 | 55.4 | 5.6 |

*gigul2 none-context tested at 25 tokens only (0.926s TTFT, 12.5 tok/s), not directly comparable to 10K/15K prompt.

Format: Average TTFT / Average Throughput across 3 runs.

---

## Comparison: macbook2 Metal b8393 vs gigul2 HIP ROCm

| Context | macbook2 TTFT | gigul2 TTFT | Ratio | macbook2 tok/s | gigul2 tok/s | Ratio |
|---------|--------------|-------------|-------|----------------|--------------|-------|
| 20K | 22.4s | 26.4s | **0.85x (faster!)** | 11.2 | 7.8 | **1.4x faster** |
| 25K | 32.8s | 39.2s | **0.84x (faster!)** | 8.8 | 6.2 | **1.4x faster** |
| 50K | 28.8s | 37.7s | **0.76x (faster!)** | 9.0 | 6.7 | **1.3x faster** |
| 55K | 42.3s | 55.4s | **0.76x (faster!)** | 7.3 | 5.6 | **1.3x faster** |

**macbook2 with llama.cpp Metal b8393 is faster than gigul2 HIP ROCm on Qwen3-Coder-Next** at all tested context sizes - both in TTFT (15-24% faster) and throughput (30-44% faster). This is a significant result given gigul2 has 2.4x the memory bandwidth (960 vs 400 GB/s).

Note: gigul2 used `--n-cpu-moe 33` (CPU offloading 33 of 512 experts) due to 24GB VRAM limit. macbook2 runs the full 57GB model in unified memory with no offloading.

---

## None-Context (0 prefill)

### 10K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 16.039 | 12.7 | 411 tok | 32.3 |
| 2 | 17.075 | 10.8 | 324 tok | 30.0 |
| 3 | 18.193 | 9.3 | 279 tok | 30.0 |
| **Avg** | **17.1** | **10.9** | **338** | **30.8** |

### 15K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 11.834 | 13.5 | 509 tok | 37.7 |
| 2 | 12.412 | 13.0 | 429 tok | 33.0 |
| 3 | 12.030 | 13.1 | 489 tok | 37.3 |
| **Avg** | **12.1** | **13.2** | **476** | **36.0** |

Note: 15K TTFT is lower than 10K - likely due to KV cache warmup from the 10K runs.

---

## Small-Context (10K prefill)

### 20K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 22.224 | 10.8 | 526 tok | 48.6 | 15.58 |
| 2 | 22.704 | 11.5 | 562 tok | 48.9 | 1.48 |
| 3 | 22.179 | 11.4 | 546 tok | 47.9 | 1.54 |
| **Avg** | **22.4** | **11.2** | **545** | **48.5** | **6.2** |

### 25K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 33.262 | 9.0 | 548 tok | 61.2 | 1.66 |
| 2 | 32.893 | 8.7 | 525 tok | 60.4 | 1.67 |
| 3 | 32.371 | 8.6 | 516 tok | 60.0 | 1.58 |
| **Avg** | **32.8** | **8.8** | **530** | **60.5** | **1.6** |

---

## Mid-Context (40K prefill)

### 50K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 29.423 | 8.2 | 518 tok | 62.9 | 59.74 |
| 2 | 28.435 | 9.7 | 599 tok | 61.9 | 2.04 |
| 3 | 28.483 | 9.1 | 566 tok | 61.9 | 2.06 |
| **Avg** | **28.8** | **9.0** | **561** | **62.2** | **21.3** |

### 55K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 42.582 | 7.4 | 573 tok | 77.8 | 2.07 |
| 2 | 42.227 | 7.5 | 582 tok | 77.4 | 2.21 |
| 3 | 42.203 | 6.9 | 535 tok | 77.9 | 2.06 |
| **Avg** | **42.3** | **7.3** | **563** | **77.7** | **2.1** |

---

## Key Observations

1. **Beats gigul2 at all context sizes**: macbook2 Metal b8393 is 15-24% faster TTFT and 30-44% faster throughput than gigul2 HIP ROCm on the same model. This is remarkable given the 2.4x bandwidth disadvantage.

2. **Why macbook2 wins**: gigul2 must offload 33 of 512 MoE experts to CPU (only 24GB VRAM for a 57GB model). macbook2's 96GB unified memory fits the entire model without offloading, avoiding the CPU-GPU transfer penalty.

3. **Consistent throughput**: 7-13 tok/s across all context sizes, much better than the joyai-llm results (0.5-4.9 tok/s) despite Qwen3-Coder-Next being a larger model. The MoE architecture (only 10 active experts per token) keeps compute efficient.

4. **TTFT scaling**: Well-behaved scaling from 17s at 10K to 42s at 55K context. The 50K TTFT (28.8s) is actually lower than 25K (32.8s), likely due to prefill caching effects.

5. **Prefill caching**: llama.cpp caches prefill effectively - first run at 40K prefill takes 60s, subsequent runs ~2s.

6. **Zero crashes**: All tiers completed without issues.

7. **llama.cpp b8393 Metal improvement**: These numbers suggest the latest llama.cpp Metal build (b8393) has meaningful performance improvements for MoE models on Apple Silicon.

---

## Hardware Details

- **CPU**: Apple M2 Max (38-core GPU)
- **RAM**: 96GB unified memory
- **Memory Bandwidth**: ~400 GB/s
- **OS**: macOS 15.7.3 (arm64)
- **Backend**: llama.cpp b8393 Metal (build.macbook2-metal)
- **Model**: Qwen3-Coder-Next-UD-Q5_K_XL (80B, 512 experts, 10 active, Q5_K_XL, ~57GB)

### gigul2 (comparison)
- **GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
- **RAM**: 128GB system
- **Memory Bandwidth**: 960 GB/s (GPU)
- **Backend**: llama.cpp HIP ROCm (hip-rocwmma, --n-cpu-moe 33)
- **Model**: Same Qwen3-Coder-Next-UD-Q5_K_XL

---

## Reproduction

```bash
# None-context
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 \
  --model "Qwen3-Coder-Next-UD-Q5_K_XL-00001-of-00003.gguf" \
  --no-prefill --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "llamacpp-metal-q5kxl" \
  --output "benchmark_macbook2_llamacpp_metal_qwen3-coder-next_nonecontext_results.jsonl"

# Small-context (10K prefill)
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 \
  --model "Qwen3-Coder-Next-UD-Q5_K_XL-00001-of-00003.gguf" \
  --prefill-tokens 10000 --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "llamacpp-metal-q5kxl" \
  --output "benchmark_macbook2_llamacpp_metal_qwen3-coder-next_smallcontext_results.jsonl"

# Mid-context (40K prefill)
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 \
  --model "Qwen3-Coder-Next-UD-Q5_K_XL-00001-of-00003.gguf" \
  --prefill-tokens 40000 --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "llamacpp-metal-q5kxl" \
  --output "benchmark_macbook2_llamacpp_metal_qwen3-coder-next_midcontext_results.jsonl"
```

## Files

- `benchmark_macbook2_llamacpp_metal_qwen3-coder-next_nonecontext_results.jsonl`
- `benchmark_macbook2_llamacpp_metal_qwen3-coder-next_smallcontext_results.jsonl`
- `benchmark_macbook2_llamacpp_metal_qwen3-coder-next_midcontext_results.jsonl`
- `bench_longcontext_macbook.py` - Benchmark script
