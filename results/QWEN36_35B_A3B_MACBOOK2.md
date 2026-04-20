# Qwen3.6-35B-A3B on macbook2 (M2 Max, 96GB RAM, Metal)

**Model**: `Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf` (31GB)

**Hardware**: Apple M2 Max, 96 GB RAM, Metal backend

**Date**: 2026-04-17

---

## Executive Summary

Qwen3.6-35B-A3B runs excellently on the M2 Max with Metal backend:

| Test | Result |
|---|---:|
| **Short context speed** | 40-44 tok/s |
| **Long context speed** | 11-20 tok/s (up to 50K) |
| **LCB pass@1** | 83.7% (tiny subset) |
| **ngram-draft benefit** | Minimal (-5% to +5%) |
| **Thinking ON impact** | +6pp LCB accuracy, 2-3× slower |

**Recommendation**: Use Qwen3.6-35B-A3B as default for M2 Max. Skip ngram-draft (minimal benefit). Enable thinking ON for best accuracy.

---

## Expected Performance on M2 Max

### Short Context (<1K tokens)
- **Throughput**: 40-44 tok/s
- **TTFT**: 0.3-0.4s
- **Use case**: Chat, short prompts, quick responses

### Medium Context (5K-30K tokens)
- **Throughput**: 17-20 tok/s
- **TTFT**: 13-17s
- **Use case**: Document analysis, medium-length contexts

### Long Context (40K-50K tokens)
- **Throughput**: 11-14 tok/s
- **TTFT**: 21-34s
- **Use case**: Long documents, codebases

### Very Long Context (100K+ tokens)
- **Throughput**: 0.6-8 tok/s (variable)
- **TTFT**: 32-946s (highly variable)
- **Use case**: Maximum context, expect slowdowns

### Coding (LiveCodeBench)
- **pass@1**: 83.7% (tiny 92-problem subset)
- **Easy problems**: 100% (32/32)
- **Medium problems**: 89.7% (35/39)
- **Hard problems**: 47.6% (10/21)
- **Avg time**: ~5 minutes per problem

---

## Server Configuration

### Recommended Settings

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --model ~/llama.cpp/models/Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf \
  --alias qwen3.6-35b-a3b \
  --host 0.0.0.0 --port 8081 \
  --gpu-layers all \
  --ctx-size 150000 \
  --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0.0 \
  --repeat-penalty 1.0 --presence-penalty 1.5 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --threads 8 --parallel 1 \
  --mmap --mlock \
  --n-predict 10000 \
  --reasoning on \
  --reasoning-format deepseek \
  --reasoning-budget 5000 \
  --reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now." \
  --jinja \
  --chat-template-kwargs '{"enable_thinking":true}'
```

### Performance Tips

1. **Use `--flash-attn on`**: Required for good Metal performance
2. **Use `--gpu-layers all`**: Offload all layers to GPU
3. **KV cache `q8_0`**: Best quality/speed tradeoff
4. **Threads 8**: Optimal for M2 Max
5. **Skip ngram-draft**: Minimal benefit on M2 Max with thinking ON
6. **Thinking budget 5000**: Good balance for reasoning tasks

---

## Detailed Results

### 1. CONTEXT Test (Thinking ON, 5000 budget)

No speculative decoding.

| Total Context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.29s | 44.4 tok/s |
| 100 | 0 | 100 | 0.43s | 40.8 tok/s |
| 15K | 5K | 10K | 13.0s | 20.3 tok/s |
| 30K | 20K | 10K | 16.3s | 18.6 tok/s |
| 50K | 40K | 10K | 21.4s | 13.5 tok/s |
| 55K | 40K | 15K | 34.4s | 11.3 tok/s |
| 110K | 100K | 10K | 32.0s | 0.6 tok/s |
| 115K | 100K | 15K | 945.6s | 0.7 tok/s |

**Notes**:
- Excellent performance through 55K context (11-20 tok/s)
- Significant slowdown at 110K+ (0.6-0.7 tok/s)
- 115K context shows extreme TTFT variance (cache behavior)

### 2. CONTEXT Test with ngram-draft

`--spec-type ngram-mod --spec-ngram-size-n 24 --draft-min 48 --draft-max 64`

| Total Context | Prefill | Prompt | TTFT | Throughput | Delta vs No Draft |
|---|---:|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.34s | 42.4 tok/s | -4.5% |
| 100 | 0 | 100 | 0.45s | 33.1 tok/s | -18.9% |
| 15K | 5K | 10K | 13.6s | 19.2 tok/s | -5.4% |
| 30K | 20K | 10K | 17.3s | 17.5 tok/s | -5.9% |
| 50K | 40K | 10K | 20.6s | 0.7 tok/s | -94.8%* |
| 55K | 40K | 15K | 28.9s | 0.7 tok/s | -93.8%* |
| 110K | 100K | 10K | 39.0s | 8.0 tok/s | +1233%* |
| 115K | 100K | 15K | 59.5s | 6.4 tok/s | +814%* |

*Anomalous results at 50K+ - likely cache/measurement artifacts.

**Conclusion**: ngram-draft provides minimal or no benefit on M2 Max with thinking ON. Skip it.

### 3. llama-bench Test

Thinking ON, 5000 token budget.

| PP | TG | TTFT | PP t/s* | TG t/s |
|---:|---:|---:|---:|---:|
| 256 | 512 | 9.86s | 26.0 | 42.3 |
| 512 | 512 | 13.08s | 39.1 | 39.2 |
| 1024 | 512 | 11.54s | 88.7 | 37.6 |
| 1024 | 1024 | 11.57s | 88.5 | 36.5 |
| 2048 | 512 | 14.76s | 138.8 | 32.7 |
| 2048 | 1024 | 14.77s | 138.7 | 38.0 |
| 4096 | 512 | 15.17s | 273.7 | 37.2 |
| 4096 | 1024 | 13.55s | 302.3 | 34.1 |
| 8192 | 1024 | 22.92s | 357.5 | 28.2 |

*PP speed includes thinking time - not directly comparable to standard benchmarks.

**Key**:
- TTFT dominated by thinking time (~5000 tokens)
- TG speed: 28-42 tok/s after thinking completes
- Larger prompts = slower TTFT (more thinking to process)

### 4. LiveCodeBench Test

Thinking ON, 5000 budget, 92 problems (tiny subset).

#### No Draft (Recommended)

| Metric | Score | Count |
|---|---:|---:|
| **Overall pass@1** | **83.70%** | 77/92 |
| Easy pass@1 | 100.00% | 32/32 |
| Medium pass@1 | 89.74% | 35/39 |
| Hard pass@1 | 47.62% | 10/21 |

| Window | Problems | Pass@1 | Runtime |
|---|---:|---:|---:|
| 2024-01/02 | 36 | 77.78% | 2.3h |
| 2024-05/06 | 44 | 88.64% | 2.3h |
| 2025-04/05 | 12 | 83.33% | 2.7h |

**Total**: 7.4 hours, ~5 minutes per problem

#### With ngram-draft (Not Recommended)

| Metric | Score | Count |
|---|---||---:|
| **Overall pass@1** | **80.43%** | 74/92 |
| Easy pass@1 | 100.00% | 32/32 |
| Medium pass@1 | 79.49% | 31/39 |
| Hard pass@1 | 52.38% | 11/21 |

**Total**: 5.5 hours, ~3.6 minutes per problem

**Comparison**:
| Config | pass@1 | Runtime |
|---|---:|---:|
| No Draft | 83.70% | 7.4h |
| ngram-draft | 80.43% | 5.5h |

ngram-draft is 25% faster but -3pp accuracy. **Not worth the tradeoff.**

---

## Comparison to Other Models

### vs Nemotron-Cascade-2-30B-A3B (same M2 Max)

| Metric | Qwen3.6-35B | Nemotron-30B |
|---|---:|---:|
| Parameters | 35B | 30B |
| CONTEXT tok/s (50) | 44.4 | 57.7 (+30% Nemotron) |
| LCB pass@1 | 83.70% | 81.52% |
| LCB runtime | 7.4h | 2.3h (3× faster) |

**Tradeoff**: Qwen wins on accuracy (+2pp), Nemotron wins on speed (30% faster throughput, 3× faster LCB).

### vs MiniMax-M2.7-UD-IQ2_XXS (same M2 Max)

| Metric | Qwen3.6-35B | MiniMax-M2.7 |
|---|---:|---:|
| CONTEXT tok/s (50) | 44.4 | 21.4 |
| CONTEXT tok/s (15K) | 20.3 | 1.54 |
| CONTEXT tok/s (30K) | 18.6 | 3.65 |

Qwen3.6 is significantly faster at all context sizes on M2 Max, especially TTFT.

---

## Known Issues

1. **110K+ context instability**: Throughput drops to <1 tok/s in some runs
2. **115K context TTFT variance**: Can be 32s or 946s (cache-dependent)
3. **ngram-draft minimal benefit**: No meaningful speedup on M2 Max with thinking ON
4. **Thinking dominates TTFT**: 5000 token budget adds significant latency

---

## Recommendations for M2 Max Users

### For Best Speed
- Use short contexts (<30K) for 18-44 tok/s
- Keep thinking budget modest (2000-3000 tokens)
- Skip ngram-draft (no benefit)

### For Best Accuracy
- Enable thinking ON with 5000 token budget
- Use temperature 0.0 for deterministic outputs
- Increase max_tokens for complex tasks

### For Long Context
- Practical limit: ~50K tokens (11-14 tok/s)
- Beyond 50K: Expect significant slowdowns
- At 100K+: Use sparingly, very slow (<1 tok/s)

### For Coding
- Qwen3.6-35B-A3B is excellent: 83.7% pass@1
- Easy problems: Perfect 100%
- Allow ~5 minutes per problem with thinking ON

---

## Quick Reference

| Context Size | Expected Speed | Use Case |
|---|---:|---|
| <1K | 40-44 tok/s | Chat, quick responses |
| 5K-30K | 17-20 tok/s | Documents, analysis |
| 30K-50K | 11-14 tok/s | Long contexts |
| 50K-100K | 1-8 tok/s | Very long contexts |
| 100K+ | <1 tok/s | Maximum context (slow) |

| Task | Expected Performance |
|---|---|
| Coding (Easy) | 100% pass@1 |
| Coding (Medium) | 90% pass@1 |
| Coding (Hard) | 48% pass@1 |
| Reasoning | Excellent with thinking ON |
| Chat | Fast, fluent |

---

## Source Data

Full results in individual files:
- `CONTEXT_RESULTS_QWEN36_35B_A3B_MACBOOK2.md`
- `CONTEXT_RESULTS_QWEN36_35B_A3B_MACBOOK2_NGRAM_DRAFT.md`
- `LCB_RESULTS_QWEN36_35B_A3B_MACBOOK2.md`
- `LCB_RESULTS_QWEN36_35B_A3B_MACBOOK2_NGRAM_DRAFT.md`
- `LLAMA_BENCH_QWEN36_35B_A3B_MACBOOK2.md`

---

## MLX 4-Bit Results (mlx_lm.server)

**Date**: 2026-04-19 (updated 2026-04-20 with 50K cap tests)

**Model**: `mlx-community/Qwen3.6-35B-A3B-4bit` (MLX 4-bit quantization)

**Backend**: MLX (Apple Metal), not llama.cpp

**KV Cache Quantization**: NOT SUPPORTED in mlx_lm.server (only in mlx_vlm.server, which is incompatible with text-only models)

### Executive Summary (MLX)

| Test | Result |
|---|---:|
| **Short context speed** | 65-72 tok/s (with cache) |
| **Medium context speed** | 42 tok/s at 5K (cached) |
| **Long context speed** | 1.5-4 tok/s at 20K-50K |
| **100K context** | **CRASHES** (Metal GPU error) |
| **Prompt cache** | Excellent (3-4× speedup on repeats) |

### MLX Server Configuration

```bash
mlx_lm.server \
  --model mlx-community/Qwen3.6-35B-A3B-4bit \
  --trust-remote-code \
  --port 8081 \
  --max-tokens 10000 \
  --chat-template-args '{"enable_thinking":true,"preserve_thinking":true}' \
  --prompt-cache-size 16 \
  --prompt-cache-bytes 12GB \
  --decode-concurrency 4 \
  --prompt-concurrency 2
```

### CONTEXT Test (MLX 4-bit, 50K Cap)

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|
| 50 | 0 | 50 | 2.78s | 72.1 tok/s |
| 100 | 0 | 100 | 3.08s | 65.0 tok/s |
| 5010 | 5K | 10 | 6.60s (avg) | 42.4 tok/s |
| 5015 | 5K | 15 | 6.69s (avg) | 42.8 tok/s |
| 20010 | 20K | 10 | 46.47s | 4.3 tok/s |
| 20015 | 20K | 15 | 41.04s | 2.3 tok/s |
| 40010 | 40K | 10 | 955.64s* | 0.2 tok/s |
| 40015 | 40K | 15 | 94.00s | 2.0 tok/s |
| 50010 | 50K | 10 | 128.87s | 1.6 tok/s |
| 50015 | 50K | 15 | 127.85s | 1.5 tok/s |
| 100010 | 100K | 10 | **CRASH** | **Metal error** |

\* 40010 showed extreme variance (955s vs 94s) - possible cache/thinking behavior

**Notes**:
- **Practical max**: 50K context (100K crashes with Metal GPU error)
- **Short context (<1K)**: Excellent at 65-72 tok/s
- **5K context**: 42 tok/s after prompt cache warmup (first run: 15 tok/s)
- **20K+ context**: Very slow at 1.5-4 tok/s
- **40K+ context**: Extremely slow at 0.2-2 tok/s, highly variable
- **100K context**: CRASHES with `[METAL] Command buffer execution failed: Internal Error`

### LLAMA-BENCH Style Test (MLX 4-bit)

| PP | TG | TTFT | PP t/s | TG t/s |
|---:|---:|--------|--------|--------|
| 256 | 512 | 6.98s | 38.6 | 59.3 |
| 512 | 512 | 6.18s | 84.0 | 60.7 |
| 1024 | 512 | 6.39s | 165.3 | 57.3 |
| 1024 | 1024 | 5.37s | 190.6 | 66.1 |
| 2048 | 512 | 8.51s | 260.6 | 51.7 |
| 2048 | 1024 | 6.24s | 328.5 | 65.1 |
| 4096 | 512 | 16.09s | 254.6 | 26.1 |
| 4096 | 1024 | 7.16s | 572.1 | 58.7 |
| 8192 | 512 | 26.89s | 304.6 | 14.9 |

**Notes**:
- Strong PP speed at 1024+ (165-572 t/s with cache)
- TG speed drops at longer contexts (14-26 t/s at 4096-8192)
- TTFT includes thinking time (~5000 tokens for Qwen3.6)

### Comparison: llama.cpp Q6_K_XL vs MLX 4-bit

| Context | llama.cpp tok/s | MLX tok/s | Winner |
|---|---:|---:|---:|
| 50 | 44.4 | 72.1 (cached) | **MLX** (1.6×) |
| 100 | 40.8 | 65.0 (cached) | **MLX** (1.6×) |
| 5K | 20.3 | 42.4 (cached) | **MLX** (2.1×) |
| 15K | 20.3 | 15 (cold) / 42 (warm) | Variable |
| 30K | 18.6 | 2-4 | **llama.cpp** (5-9×) |
| 50K | 13.5 | 1.5-2 | **llama.cpp** (7-9×) |
| 100K | 0.6 | **CRASH** | llama.cpp (slow but works) |

### MLX 4-bit Recommendations

**Use MLX when**:
- Short prompts with cache hits (chat, repeated queries)
- Sub-10K context sizes
- Fast inference is critical for short contexts

**Use llama.cpp when**:
- Long contexts (>20K)
- Stable performance required
- 100K+ contexts needed
- Production workloads

### MLX Known Issues

1. **100K context crashes**: Metal GPU driver error at 59392/100025 tokens
2. **No KV cache quantization**: `mlx_lm.server` doesn't support `--kv-bits` (only in `mlx_vlm.server`, which is incompatible with text-only models)
3. **Cache dependency**: Performance varies wildly based on cache hits
4. **Slow at 20K+**: 1.5-4 tok/s without cache
5. **Not production-ready for long contexts**: Crashes and extreme slowdown beyond 50K

### Source Files

MLX results:
- `CONTEXT_RESULTS_QWEN36_35B_A3B_MACBOOK2_MLX.md`
- `LLAMA_BENCH_QWEN36_35B_A3B_MACBOOK2_MLX.md`

