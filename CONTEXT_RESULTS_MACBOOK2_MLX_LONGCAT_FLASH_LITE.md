# Context Benchmark Results - LongCat-Flash-Lite MLX-5.5bit on macbook2

**Date**: 2026-02-26
**Model**: LongCat-Flash-Lite (meituan-longcat/LongCat-Flash-Lite), MLX 5.5-bit quantization
**Quant source**: inferencerlabs/LongCat-Flash-Lite-MLX-5.5bit
**Hardware**: Apple M2 Max, 92GB unified memory, ~400 GB/s bandwidth
**Model size on disk**: ~50 GB (5.5-bit)
**Architecture**: longcat_flash_ngram (MoE: 256 experts, 12 active per token, 14 layers, MLA attention)
**Max position embeddings**: 327,680 (model config)
**Server**: mlx_lm 0.30.7, mlx 0.30.6, port 8081
**Notes**: Required patch to mlx_lm/models/longcat_flash.py sanitize() for mxfp4 compat (see ~/LJ-mlx/scripts/patch-longcat-flash-mxfp4.patch)

---

## Summary Table

| Tier | Total Context | TTFT (s) | Throughput (tok/s) | Notes |
|------|--------------|----------|-------------------|-------|
| **none** | 25 | 0.4 | 52.9 | Baseline, no prefill |
| **none** | 50 | 0.5 | 53.4 | Baseline, no prefill |
| **none** | 100 | 0.8 | 40.8 | Baseline, no prefill |
| **small** | 20K | 44.7 | 9.5 | 10K prefill + 10K prompt |
| **small** | 25K | 60.2 | 7.3 | 10K prefill + 15K prompt |
| **long** | 50K | 146.7 | 3.5 | 40K prefill + 10K prompt |
| **long** | 55K | 175.2 | 3.6 | 40K prefill + 15K prompt |
| **longlong** | 110K+ | CRASH | CRASH | Metal GPU Internal Error at ~45K/55K tokens |

Format: Average TTFT / Average Throughput across 3 runs.

---

## Scaling Analysis

| Context | Throughput | vs Baseline (53 tok/s) | TTFT |
|---------|-----------|----------------------|------|
| ~50 tokens | 53.4 tok/s | 1.00x | 0.5s |
| ~20K tokens | 9.5 tok/s | 0.18x | 44.7s |
| ~25K tokens | 7.3 tok/s | 0.14x | 60.2s |
| ~50K tokens | 3.5 tok/s | 0.07x | 146.7s |
| ~55K tokens | 3.6 tok/s | 0.07x | 175.2s |

**Key observations**:
- Massive throughput degradation with context: 53 tok/s baseline drops to 3.5 tok/s at 50K (15x slower)
- TTFT scales roughly linearly with context size (~3s per 1K tokens of context)
- 100K+ context causes Metal GPU crash (Internal Error 0000000e) — likely OOM with ~50GB model + KV cache
- Throughput relatively stable between 50K-55K (3.5-3.6 tok/s), suggesting decode is memory-bandwidth bound at that point

---

## Tier: None-Context (No Prefill)

### 25-token prompts

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 0.353 | 65.7 | 190 tok | 2.9 |
| 2 | 0.390 | 45.4 | 126 tok | 2.8 |
| 3 | 0.423 | 47.4 | 126 tok | 2.7 |
| **Avg** | **0.389** | **52.9** | **147** | **2.8** |

### 50-token prompts

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 0.471 | 55.1 | 340 tok | 6.2 |
| 2 | 0.477 | 53.1 | 236 tok | 4.5 |
| 3 | 0.497 | 52.0 | 179 tok | 3.4 |
| **Avg** | **0.482** | **53.4** | **252** | **4.7** |

### 100-token prompts

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 0.753 | 42.8 | 584 tok | 13.7 |
| 2 | 0.743 | 41.7 | 582 tok | 14.0 |
| 3 | 0.775 | 38.0 | 540 tok | 14.2 |
| **Avg** | **0.757** | **40.8** | **569** | **14.0** |

---

## Tier: Small-Context (10K Prefill)

### 10K prompt (20K total context)

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 44.949 | 9.8 | 592 tok | 60.5 |
| 2 | 44.891 | 9.2 | 551 tok | 60.2 |
| 3 | 44.144 | 9.6 | 568 tok | 59.3 |
| **Avg** | **44.7** | **9.5** | **570** | **60.0** |

### 15K prompt (25K total context)

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 60.322 | 7.2 | 554 tok | 77.0 |
| 2 | 60.200 | 7.4 | 567 tok | 76.7 |
| 3 | 59.968 | 7.4 | 561 tok | 76.3 |
| **Avg** | **60.2** | **7.3** | **561** | **76.7** |

---

## Tier: Long-Context (40K Prefill)

### 10K prompt (50K total context)

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 143.653 | 3.8 | 629 tok | 165.2 |
| 2 | 145.725 | 3.4 | 564 tok | 168.1 |
| 3 | 150.810 | 3.4 | 593 tok | 173.3 |
| **Avg** | **146.7** | **3.5** | **595** | **168.8** |

### 15K prompt (55K total context)

| Run | TTFT (s) | Throughput (tok/s) | Generated | Total (s) |
|-----|----------|-------------------|-----------|-----------|
| 1 | 179.011 | 3.5 | 713 tok | 201.6 |
| 2 | 172.458 | 3.6 | 696 tok | 195.0 |
| 3 | 174.064 | 3.5 | 696 tok | 196.5 |
| **Avg** | **175.2** | **3.6** | **702** | **197.7** |

---

## Tier: LongLong-Context (100K Prefill) — FAILED

**Result**: Server crash during prefill at ~45K out of 55K tokens being processed.

**Error**: Metal GPU Internal Error (0000000e) — `Command buffer execution failed: Internal Error`
- Process terminated with `Abort trap: 6`
- Crash occurred in `libmlx.dylib` Metal command buffer completion handler
- Root cause: GPU memory exhaustion — ~50GB model weights + KV cache for 100K+ tokens exceeds available unified memory

**Recommendation**: Use 4-bit (mxfp4) quantization (~36GB) for 100K+ context, or cap context at ~55K tokens with 5.5-bit.

---

## Cross-System Comparison (at ~50K-55K total context)

| System | Model | Quant | TTFT (s) | Throughput (tok/s) |
|--------|-------|-------|----------|-------------------|
| macbook2 M2 Max | LongCat-Flash-Lite 69B | MLX 5.5-bit | 147-175 | 3.5-3.6 |
| macbook2 M2 Max | GLM-4.7-Flash 9B | vLLM-MLX 8-bit | 217-225 | 2.7 |
| gigul2 7900 XTX | GLM-4.7-Flash 9B | llama.cpp HIP Q4 | 21-33 | 16-22 |

**Notable**: The 69B LongCat model on MLX is actually *faster* at 50K context than the 9B GLM-4.7-Flash on vLLM-MLX, despite being 7.5x larger. This suggests vLLM-MLX has significant overhead at long context lengths, or MLA (Multi-Latent Attention) in LongCat is more efficient than standard MoE attention in GLM-4.7-Flash.
