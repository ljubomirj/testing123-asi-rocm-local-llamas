# Context Benchmark Results - joyai-llm-flash Q6_K on macbook2 (llama.cpp Metal)

**Date**: 2026-02-17
**Model**: joyai-llm-flash (joyai-llm-flash-q6_k.gguf), Q6_K quantization
**Hardware**: Apple M2 Max, 96GB unified memory, ~400 GB/s bandwidth
**Model size on disk**: ~40.23 GB (48.9B parameters)
**Architecture**: MoE, n_embd=2048, n_ctx_train=131072, vocab=129280
**Backend**: llama.cpp b8351 Metal (build.macbook2-metal)
**Server config**: n_ctx=128000, 4 slots, ChatML template
**Port**: 127.0.0.1:8081

---

## Summary Table

| Tier | Total Context | TTFT (s) | Throughput (tok/s) | Notes |
|------|--------------|----------|-------------------|-------|
| **none** | 10K | 35.7 | 4.9 | No prefill |
| **none** | 15K | 34.0 | 4.2 | No prefill |
| **small** | 20K | 79.2 | 2.6 | 10K prefill |
| **small** | 25K | 128.7 | 2.2 | 10K prefill |
| **mid** | 50K | 193.3 | 1.2 | 40K prefill |
| **mid** | 55K | 300.7 | 0.9 | 40K prefill |
| **large** | 90K | 453.7 | 0.7 | 80K prefill |
| **large** | 95K | 563.2 | 0.5 | 80K prefill |

Format: Average TTFT / Average Throughput across 3 runs.

---

## None-Context (0 prefill)

### 10K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 35.155 | 5.4 | 702 tok | 129.7 |
| 2 | 37.865 | 5.3 | 652 tok | 122.0 |
| 3 | 34.193 | 3.8 | 287 tok | 75.7 |
| **Avg** | **35.7** | **4.9** | **547** | **109.1** |

### 15K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 33.388 | 4.4 | 671 tok | 154.1 |
| 2 | 34.930 | 4.0 | 617 tok | 153.3 |
| 3 | 33.794 | 4.1 | 529 tok | 130.3 |
| **Avg** | **34.0** | **4.2** | **606** | **145.9** |

---

## Small-Context (10K prefill)

### 20K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 78.447 | 2.7 | 636 tok | 232.8 | 26.93 |
| 2 | 80.592 | 2.5 | 590 tok | 235.8 | 2.09 |
| 3 | 78.663 | 2.7 | 621 tok | 230.4 | 2.15 |
| **Avg** | **79.2** | **2.6** | **616** | **233.0** | **10.4** |

### 25K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 131.305 | 2.4 | 742 tok | 313.3 | 1.97 |
| 2 | 135.169 | 1.9 | 612 tok | 318.1 | 1.99 |
| 3 | 119.752 | 2.2 | 659 tok | 296.5 | 1.86 |
| **Avg** | **128.7** | **2.2** | **671** | **309.3** | **1.9** |

---

## Mid-Context (40K prefill)

### 50K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 190.107 | 1.2 | 622 tok | 514.9 | 270.55 |
| 2 | 196.957 | 1.2 | 634 tok | 524.7 | 6.85 |
| 3 | 192.949 | 1.3 | 655 tok | 521.3 | 6.75 |
| **Avg** | **193.3** | **1.2** | **637** | **520.3** | **94.7** |

### 55K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 316.041 | 0.9 | 585 tok | 676.9 | 6.86 |
| 2 | 285.193 | 0.9 | 541 tok | 636.6 | 6.65 |
| 3 | 300.978 | 1.1 | 707 tok | 660.1 | 6.63 |
| **Avg** | **300.7** | **0.9** | **611** | **657.9** | **6.7** |

---

## Large-Context (80K prefill)

### 90K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 647.584 | 0.6 | 686 tok | 1248.4 | 600.02* |
| 2 | 375.819 | 0.6 | 610 tok | 987.2 | 14.46 |
| 3 | 337.596 | 0.8 | 706 tok | 901.6 | 12.98 |
| **Avg** | **453.7** | **0.7** | **667** | **1045.7** | **209.2** |

*Run 1 prefill timed out at 600s (script timeout). Runs 2-3 used cached prefill (~13s).

### 95K Total Context

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) | Prefill (s) |
|-----|----------|-------------------|-----------|-----------|-------------|
| 1 | 567.267 | 0.5 | 418 tok | 897.0 | 13.61 |
| 2 | 550.694 | 0.6 | 695 tok | 1178.8 | 13.55 |
| 3 | 571.701 | 0.6 | 660 tok | 1165.3 | 13.63 |
| **Avg** | **563.2** | **0.5** | **591** | **1080.4** | **13.6** |

---

## Key Observations

1. **No crashes**: llama.cpp Metal handled all context sizes up to 95K without any crashes or OOM, unlike the MLX backends on GLM-4.7-Flash.

2. **TTFT scaling**: Roughly O(n^2) as expected for attention:
   - 10K: 35.7s
   - 20K: 79.2s (2.2x for 2x context)
   - 50K: 193.3s (5.4x for 5x context)
   - 90K: 453.7s (12.7x for 9x context)

3. **Throughput degradation**: Throughput drops significantly with context size, from 4.9 tok/s at 10K down to 0.5 tok/s at 95K. This is expected as each generated token requires attending to the full context.

4. **Prefill caching**: llama.cpp effectively caches the prefill context. First run prefill is slow (270s for 40K, 600s+ for 80K), but subsequent runs with the same prefix complete in ~2-14s.

5. **Model size impact**: At 48.9B parameters (Q6_K, ~40GB), this model is substantially larger than GLM-4.7-Flash (~30B active). The Q6_K quantization preserves more precision but requires more memory bandwidth per token.

6. **Practical limits**: 50K context is slow but usable (~3 min TTFT). 90K+ context pushes TTFT above 7 minutes with sub-1 tok/s throughput.

---

## Hardware Details

- **CPU**: Apple M2 Max (38-core GPU)
- **RAM**: 96GB unified memory
- **Memory Bandwidth**: ~400 GB/s
- **OS**: macOS 15.7.3 (arm64)
- **Backend**: llama.cpp b8351 Metal (build.macbook2-metal)
- **Model**: joyai-llm-flash-q6_k.gguf (Q6_K, ~40.23 GB on disk)

---

## Reproduction

```bash
# None-context
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 --model "joyai-llm-flash-q6_k.gguf" \
  --no-prefill --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "llamacpp-metal-q6k" \
  --output "benchmark_macbook2_llamacpp_metal_joyai-llm-flash_nonecontext_results.jsonl"

# Small-context (10K prefill)
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 --model "joyai-llm-flash-q6_k.gguf" \
  --prefill-tokens 10000 --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "llamacpp-metal-q6k" \
  --output "benchmark_macbook2_llamacpp_metal_joyai-llm-flash_smallcontext_results.jsonl"

# Mid-context (40K prefill)
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 --model "joyai-llm-flash-q6_k.gguf" \
  --prefill-tokens 40000 --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "llamacpp-metal-q6k" \
  --output "benchmark_macbook2_llamacpp_metal_joyai-llm-flash_midcontext_results.jsonl"

# Large-context (80K prefill)
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 --model "joyai-llm-flash-q6_k.gguf" \
  --prefill-tokens 80000 --prompt-tokens 10000,15000 --runs 3 --max-tokens 512 \
  --backend-label "llamacpp-metal-q6k" \
  --output "benchmark_macbook2_llamacpp_metal_joyai-llm-flash_largecontext_results.jsonl"
```

## Files

- `benchmark_macbook2_llamacpp_metal_joyai-llm-flash_nonecontext_results.jsonl`
- `benchmark_macbook2_llamacpp_metal_joyai-llm-flash_smallcontext_results.jsonl`
- `benchmark_macbook2_llamacpp_metal_joyai-llm-flash_midcontext_results.jsonl`
- `benchmark_macbook2_llamacpp_metal_joyai-llm-flash_largecontext_results.jsonl`
- `bench_longcontext_macbook.py` - Benchmark script
