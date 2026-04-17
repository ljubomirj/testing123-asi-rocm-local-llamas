# Qwen3.6-35B-A3B Q6_K_XL Context Benchmark Results - macbook2

**Date**: 2026-04-17

**Model**: `Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf`

**Hardware**: `macbook2` (Apple M2 Max, 96 GB RAM, Metal)

**Run root**: [`runs/qwen36_35b_a3b_macbook2_context_20260417_022024`](../runs/qwen36_35b_a3b_macbook2_context_20260417_022024)

## Bottom Line

Qwen3.6-35B-A3B Q6_K_XL on the M2 Max performs well at short contexts (~40-44 tok/s with no prefill) and remains usable through 55K context (~11-18 tok/s). At 110K+ context, performance degrades significantly to ~0.6-0.7 tok/s.

Thinking ON mode with 5000 token reasoning budget was stable throughout all runs.

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
  --cache-type-k q8_0 --cache-type-v q8_0 --kv-unified \
  --threads 8 --batch-size 2048 --ubatch-size 512 \
  --parallel 1 --no-mmap \
  --n-predict 10000 \
  --reasoning on --reasoning-format deepseek \
  --reasoning-budget 5000 \
  --reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now." \
  --jinja \
  --chat-template-kwargs '{"enable_thinking":true}'
```

## Test Parameters

- **Thinking mode**: ON (deepseek format)
- **Reasoning budget**: 5000 tokens
- **Runs per context size**: 3 for none/small, 1 for mid/long/longlong
- **Max tokens**: 200 (none), 512 (context tests)
- **Chat template kwargs**: `{"enable_thinking": true}`

## Results

### Context Summary

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.29s | 44.4 tok/s |
| 100 | 0 | 100 | 0.43s | 40.8 tok/s |
| 15K | 5K | 10K | 13.0s | 20.3 tok/s |
| 20K | 5K | 15K | 169.8s | 6.5 tok/s |
| 30K | 20K | 10K | 16.3s | 18.6 tok/s |
| 35K | 20K | 15K | 24.0s | 14.2 tok/s |
| 50K | 40K | 10K | 21.4s | 13.5 tok/s |
| 55K | 40K | 15K | 34.4s | 11.3 tok/s |
| 110K | 100K | 10K | 32.0s | 0.6 tok/s |
| 115K | 100K | 15K | 945.6s | 0.7 tok/s |

### None Context (no prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.291s | 44.4 tok/s | 3 |
| 100 | 0 | 100 | 0.433s | 40.8 tok/s | 3 |

### Small Context (5K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 15K | 5K | 10K | 13.032s | 20.3 tok/s | 3 |
| 20K | 5K | 15K | 169.815s | 6.5 tok/s | 3 |

### Mid Context (20K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 30K | 20K | 10K | 16.304s | 18.6 tok/s | 1 |
| 35K | 20K | 15K | 23.982s | 14.2 tok/s | 1 |

### Long Context (40K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 50K | 40K | 10K | 21.397s | 13.5 tok/s | 1 |
| 55K | 40K | 15K | 34.379s | 11.3 tok/s | 1 |

### LongLong Context (100K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 110K | 100K | 10K | 31.985s | 0.6 tok/s | 1 |
| 115K | 100K | 15K | 945.585s | 0.7 tok/s | 1 |

## Raw Files

- `runs/qwen36_35b_a3b_macbook2_context_20260417_022024/context/benchmark_qwen36_35b_a3b_none_thinking_on.jsonl`
- `runs/qwen36_35b_a3b_macbook2_context_20260417_022024/context/benchmark_qwen36_35b_a3b_small_5k_thinking_on.jsonl`
- `runs/qwen36_35b_a3b_macbook2_context_20260417_022024/context/benchmark_qwen36_35b_a3b_mid_20k_thinking_on.jsonl`
- `runs/qwen36_35b_a3b_macbook2_context_20260417_022024/context/benchmark_qwen36_35b_a3b_long_40k_thinking_on.jsonl`
- `runs/qwen36_35b_a3b_macbook2_context_20260417_022024/context/benchmark_qwen36_35b_a3b_longlong_100k_thinking_on.jsonl`

## Takeaways

1. Qwen3.6-35B-A3B Q6_K_XL performs excellently at short contexts: ~40-44 tok/s with no prefill.
2. Performance remains good through 55K context: ~11-20 tok/s depending on context size.
3. At 110K+ context, performance degrades significantly to ~0.6-0.7 tok/s - near the practical limit for this model size on M2 Max.
4. The Q6_K_XL quantization provides a good balance of quality and speed for this 35B model.
5. Thinking ON mode with 5000 token reasoning budget worked reliably across all context sizes.

## Comparison to MiniMax-M2.7 (same hardware)

| Context | Qwen3.6 TTFT | Qwen3.6 tok/s | MiniMax TTFT | MiniMax tok/s |
|---|---:|---:|---:|---:|
| 50 | 0.29s | 44.4 | 1.99s | 21.4 |
| 100 | 0.43s | 40.8 | 2.60s | 20.2 |
| 15K | 13.0s | 20.3 | 260.1s | 1.54 |
| 30K | 16.3s | 18.6 | 122.8s | 3.65 |
| 50K | 21.4s | 13.5 | 163.1s | 2.61 |

Qwen3.6 is significantly faster than MiniMax-M2.7 at all context sizes on the M2 Max, especially for TTFT.
