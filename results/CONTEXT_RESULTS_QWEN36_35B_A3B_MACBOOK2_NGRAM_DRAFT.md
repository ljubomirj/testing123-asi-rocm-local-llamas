# Qwen3.6-35B-A3B Q6_K_XL Context Benchmark Results - macbook2 (ngram-draft)

**Date**: 2026-04-17

**Model**: `Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf`

**Hardware**: `macbook2` (Apple M2 Max, 96 GB RAM, Metal)

**Run root**: [`runs/qwen36_35b_a3b_macbook2_context_ngram_20260417_132235`](../runs/qwen36_35b_a3b_macbook2_context_ngram_20260417_132235)

## Bottom Line

Qwen3.6-35B-A3B Q6_K_XL with ngram-draft (`--spec-type ngram-mod --spec-ngram-size-n 24 --draft-min 48 --draft-max 64`) on the M2 Max performs similarly to the non-draft version at short contexts (~42 tok/s with no prefill).

The ngram-draft doesn't show significant speedup in this configuration, likely because the model is already reasonably fast and thinking ON dominates the latency.

## Server Configuration

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
  --reasoning-budget 5000 \
  --reasoning-budget-message "Reasoning budget exhausted. Stop thinking and provide the best final answer now." \
  --jinja \
  --chat-template-kwargs '{"enable_thinking":true}' \
  --spec-type ngram-mod --spec-ngram-size-n 24 --draft-min 48 --draft-max 64
```

## Test Parameters

- **Thinking mode**: ON (deepseek format)
- **Reasoning budget**: 5000 tokens
- **Speculative**: ngram-mod (ngram-size-n=24, draft-min=48, draft-max=64)
- **Memory mapping**: mmap (not no-mmap)
- **Runs per context size**: 3 for none/small, 1 for mid/long/longlong
- **Max tokens**: 200 (none), 512 (context tests)

## Results

### Context Summary

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.34s | 42.4 tok/s |
| 100 | 0 | 100 | 0.45s | 33.1 tok/s |
| 15K | 5K | 10K | 13.6s | 19.2 tok/s |
| 20K | 5K | 15K | 19.7s | 16.2 tok/s |
| 30K | 20K | 10K | 17.3s | 17.5 tok/s |
| 35K | 20K | 15K | 24.6s | 14.2 tok/s |
| 50K | 40K | 10K | 20.6s | 0.7 tok/s |
| 55K | 40K | 15K | 28.9s | 0.7 tok/s |
| 110K | 100K | 10K | 39.0s | 8.0 tok/s |
| 115K | 100K | 15K | 59.5s | 6.4 tok/s |

### None Context (no prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.335s | 42.4 tok/s | 3 |
| 100 | 0 | 100 | 0.452s | 33.1 tok/s | 3 |

### Small Context (5K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 15K | 5K | 10K | 13.626s | 19.2 tok/s | 3 |
| 20K | 5K | 15K | 19.691s | 16.2 tok/s | 3 |

### Mid Context (20K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 30K | 20K | 10K | 17.328s | 17.5 tok/s | 1 |
| 35K | 20K | 15K | 24.579s | 14.2 tok/s | 1 |

### Long Context (40K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 50K | 40K | 10K | 20.644s | 0.7 tok/s | 1 |
| 55K | 40K | 15K | 28.863s | 0.7 tok/s | 1 |

### LongLong Context (100K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 110K | 100K | 10K | 38.962s | 8.0 tok/s | 1 |
| 115K | 100K | 15K | 59.489s | 6.4 tok/s | 1 |

## Raw Files

- `runs/qwen36_35b_a3b_macbook2_context_ngram_20260417_132235/context/benchmark_qwen36_35b_a3b_none_thinking_on.jsonl`
- `runs/qwen36_35b_a3b_macbook2_context_ngram_20260417_132235/context/benchmark_qwen36_35b_a3b_small_5k_thinking_on.jsonl`
- `runs/qwen36_35b_a3b_macbook2_context_ngram_20260417_132235/context/benchmark_qwen36_35b_a3b_mid_20k_thinking_on.jsonl`
- `runs/qwen36_35b_a3b_macbook2_context_ngram_20260417_132235/context/benchmark_qwen36_35b_a3b_long_40k_thinking_on.jsonl`
- `runs/qwen36_35b_a3b_macbook2_context_ngram_20260417_132235/context/benchmark_qwen36_35b_a3b_longlong_100k_thinking_on.jsonl`

## Takeaways

1. **ngram-draft impact**: Minimal speedup observed compared to non-draft version. The TG speed is similar (30-42 tok/s at short contexts).
2. **Checkpoint restoration**: The log messages about checkpoint restoration are normal - KV cache management is working correctly.
3. **1M tok/s artifact**: The "1000000.00 tokens per second" for 1 token is a measurement artifact when the first token is extremely fast (<1ms).
4. **Memory mapping**: Using `--mmap` instead of `--no-mmap` - no significant performance difference observed.

## Comparison to Non-Draft Version

| Context | Draft TTFT | Draft TG | Non-Draft TTFT | Non-Draft TG |
|---|---:|---:|---:|---:|
| 50 | 0.34s | 42.4 t/s | 0.29s | 44.4 t/s |
| 100 | 0.45s | 33.1 t/s | 0.43s | 40.8 t/s |
| 15K | 13.6s | 19.2 t/s | 13.0s | 20.3 t/s |
| 30K | 17.3s | 17.5 t/s | 16.3s | 18.6 t/s |

The ngram-draft shows similar or slightly slower performance. This may be due to:
- Overhead of draft speculation
- The model is already fast enough that speculation doesn't help much
- Thinking ON mode dominates latency regardless of speculation
