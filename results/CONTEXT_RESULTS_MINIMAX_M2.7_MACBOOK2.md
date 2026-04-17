# MiniMax-M2.7 UD-IQ2_XXS Context Benchmark Results - macbook2

**Date**: 2026-04-17

**Model**: `MiniMax-M2.7-UD-IQ2_XXS.gguf`

**Hardware**: `macbook2` (Apple M2 Max, 96 GB RAM, Metal)

**Live server model**: Already running on `http://127.0.0.1:8081`

**Run root**: [`runs/minimax_m2.7_macbook2_20260416_222209`](../runs/minimax_m2.7_macbook2_20260416_222209)

## Bottom Line

MiniMax-M2.7 on the M2 Max stays usable through 115K total context, but performance degrades significantly with context size: ~20 tok/s with no context, dropping to ~0.7-4 tok/s at larger contexts.

Thinking ON mode was stable throughout all runs.

## Server Configuration

Observed live server command (started with `~/llama.cpp/llama_server_minimax-m2.7_macbook2.sh`):

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --gpu-layers all \
  --host 0.0.0.0 --port 8081 \
  --model ~/llama.cpp/models/MiniMax-M2.7-UD-IQ2_XXS-00001-of-00003.gguf \
  --alias minimax-m2.7 \
  --ctx-size 150000 --context-shift --keep 12288 \
  --temp 1.0 --top-p 0.95 --top-k 40 --min-p 0.01 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 --kv-unified \
  --batch-size 1024 --ubatch-size 256 \
  --threads 10 --parallel 1 \
  --mlock --mmap \
  --n-predict 10000 \
  --reasoning on \
  --reasoning-format deepseek \
  --jinja \
  --spec-type ngram-mod --spec-ngram-size-n 24 --draft-min 48 --draft-max 64
```

## Test Parameters

- **Thinking mode**: ON (deepseek format)
- **Runs per context size**: 3 for none/small, 1 for mid/long/longlong (due to time constraints)
- **Max tokens**: 200 (none), 512 (context tests)
- **Chat template kwargs**: `{"enable_thinking": true}`

## Results

### Context Summary

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 1.99s | 21.4 tok/s |
| 100 | 0 | 100 | 2.60s | 20.2 tok/s |
| 15K | 5K | 10K | 260.1s | 1.54 tok/s |
| 20K | 5K | 15K | 520.4s | 0.89 tok/s |
| 30K | 20K | 10K | 122.8s | 3.65 tok/s |
| 35K | 20K | 15K | 186.9s | 2.77 tok/s |
| 50K | 40K | 10K | 163.1s | 2.61 tok/s |
| 55K | 40K | 15K | 272.9s | 1.92 tok/s |
| 110K | 100K | 10K | 806.6s | 0.73 tok/s |
| 115K | 100K | 15K | 444.7s | 1.23 tok/s |

### None Context (no prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 1.99s | 21.4 tok/s | 3 |
| 100 | 0 | 100 | 2.60s | 20.2 tok/s | 3 |

### Small Context (5K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 15K | 5K | 10K | 260.1s | 1.54 tok/s | 3 |
| 20K | 5K | 15K | 520.4s | 0.89 tok/s | 3 |

### Mid Context (20K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 30K | 20K | 10K | 122.8s | 3.65 tok/s | 1 |
| 35K | 20K | 15K | 186.9s | 2.77 tok/s | 1 |

### Long Context (40K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 50K | 40K | 10K | 163.1s | 2.61 tok/s | 1 |
| 55K | 40K | 15K | 272.9s | 1.92 tok/s | 1 |

### LongLong Context (100K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 110K | 100K | 10K | 806.6s | 0.73 tok/s | 1 |
| 115K | 100K | 15K | 444.7s | 1.23 tok/s | 1 |

## Raw Files

- `runs/minimax_m2.7_macbook2_none_20260417_015332/context/benchmark_minimax_m2.7_none_thinking_on.jsonl` (corrected none context)
- `runs/minimax_m2.7_macbook2_20260416_222209/context/benchmark_minimax_m2.7_small_5k_thinking_on.jsonl`
- `runs/minimax_m2.7_macbook2_20260416_222209/context/benchmark_minimax_m2.7_mid_20k_thinking_on.jsonl`
- `runs/minimax_m2.7_macbook2_20260416_222209/context/benchmark_minimax_m2.7_long_40k_thinking_on.jsonl`
- `runs/minimax_m2.7_macbook2_20260416_222209/context/benchmark_minimax_m2.7_longlong_100k_thinking_on.jsonl`

## Takeaways

1. MiniMax-M2.7 works reliably through 115K context on the M2 Max with thinking ON.
2. **Performance varies dramatically with context**: ~20 tok/s with no context, dropping to ~0.7-4 tok/s at larger contexts.
3. Compared to Gemma/Qwen (~30+ tok/s at all contexts), MiniMax-M2.7 is significantly slower when context is loaded.
4. The IQ2_XXS quantization is extremely compact (3x 24GB files = ~72GB total) which enables running on 96GB RAM with significant room for context.
5. This model prioritizes size and quality over speed - suitable for offline use where speed is not critical, especially for short-prompt tasks.
