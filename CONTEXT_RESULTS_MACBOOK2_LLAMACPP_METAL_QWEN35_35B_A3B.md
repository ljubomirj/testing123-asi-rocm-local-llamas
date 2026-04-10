# Qwen3.5-35B-A3B Context Benchmark Results - macbook2

**Model**: Qwen3.5-35B-A3B-UD-Q8_K_XL.gguf (MoE, 35B params, 8 experts active)
**Quantization**: Q8_K_XL (~36 GB model size)
**Hardware**: macbook2 (Apple M2 Max, 96GB RAM, Metal backend)
**Software**: llama.cpp build 8466
**Test Date**: 2026-03-01

## Server Configuration

### 6-Thread Configuration (Default)
```
~/llama.cpp/build/bin/llama-server \
  --ctx-size 131072 \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Qwen3.5-35B-A3B-UD-Q8_K_XL.gguf \
  --temp 1.0 --top-p 0.95 --min-p 0.01 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --jinja \
  --cache-ram 16384 --cache-reuse 512 \
  --cache-prompt \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 6 --threads 6 \
  --mlock --kv-unified
```

### Single-Thread Configuration (--parallel 1)
```
~/llama.cpp/build/bin/llama-server \
  --ctx-size 131072 \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Qwen3.5-35B-A3B-UD-Q8_K_XL.gguf \
  --temp 1.0 --top-p 0.95 --min-p 0.01 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --jinja \
  --cache-ram 16384 --cache-reuse 512 \
  --cache-prompt \
  --parallel 1 \
  --mlock --kv-unified
```

---

## Results Summary

### None Context (No Prefill, Small Prompts)

| Threads | Context | TTFT  | Throughput |
|---------|---------|-------|------------|
| 6       | 25      | 0.29s | 34.5 tok/s |
| 6       | 50      | 0.33s | 28.7 tok/s |
| 6       | 100     | 0.43s | 31.0 tok/s |
| 1       | 25      | 0.27s | 35.4 tok/s |
| 1       | 50      | 0.31s | 33.7 tok/s |
| 1       | 100     | 0.40s | 28.2 tok/s |

### 6-Thread Forced-Context Matrix (March 1 Baseline)

| Threads | Context | Prefill | TTFT | Throughput |
|---------|---------|---------|------|------------|
| 6       | Small (15K) | 5K | 13.01s | 18.0 tok/s |
| 6       | Small (20K) | 5K | 21.73s | 13.7 tok/s |
| 6       | Mid (30K) | 20K | 16.71s | 14.8 tok/s |
| 6       | Mid (35K) | 20K | 25.73s | 11.7 tok/s |
| 6       | Long (50K) | 40K | 22.56s | 11.4 tok/s |
| 6       | Long (55K) | 40K | 31.51s | 10.1 tok/s |
| 6       | Longlong (110K) | 100K | 34.83s | 7.8 tok/s |
| 6       | Longlong (115K) | 100K | 54.02s | 6.5 tok/s |

### 1-Thread Legacy Comparison Subset

| Threads | Context | Prefill | TTFT | Throughput |
|---------|---------|---------|------|------------|
| 1       | Small (~12K) | 10K | 3.60s | 24.5 tok/s |
| 1       | Mid (~25K) | 20K | 8.86s | 17.8 tok/s |
| 1       | Long (50K) | 40K | 22.54s | 11.4 tok/s |
| 1       | Long (55K) | 40K | 32.90s | 9.4 tok/s |
| 1       | Longlong (70K) | 60K | 25.81s | 10.4 tok/s |
| 1       | Longlong (75K) | 60K | 38.51s | 8.4 tok/s |

---

## Key Observations

1. **The March 1 file actually contained two old scenario sets**: a full 6-thread forced-context matrix and a smaller 1-thread comparison subset. They are now labeled separately so the context sizes line up with the raw files.

2. **6-thread TTFT scaling is still smooth but not linear**: it rises from `13.01s` at 15K total context to `54.02s` at 115K total context, with the steepest jumps around 20K, 35K, 55K, and 115K.

3. **6-thread decode throughput degrades steadily with context**: from `18.0 tok/s` at 15K down to `6.5 tok/s` at 115K.

4. **Cache effectiveness is substantial at larger prefills**: the 40K and 100K prefill runs drop from large cold-start costs to roughly `1.5-2.8s` on warm repeats in the raw benchmark files.

---

## Comparison to GLM-4.7-Flash (Q4_K_XL)

| Metric | Qwen3.5-35B-A3B (Q8) | GLM-4.7-Flash (Q4) |
|--------|---------------------|-------------------|
| Model Size | 36 GB | ~17 GB |
| 50K TTFT | 22.56s | 173s |
| 50K Throughput | 11.4 tok/s | 0.93 tok/s |
| None-context TTFT | 0.29s | ~2-3s (LM Studio) |

The Qwen3.5-35B-A3B model shows significantly better performance on the same hardware despite being larger and more heavily quantized.

---

## 2026-03-26 Rerun With Current Wrapper

This rerun used the current macbook2 wrapper at [run_llama_qwen_wrapper_macbook2.sh](/Users/ljubomir/llama.cpp/run_llama_qwen_wrapper_macbook2.sh) and the same model file:

- `~/llama.cpp/models/Qwen3.5-35B-A3B-UD-Q8_K_XL.gguf`
- Results directory: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_162504`
- Raw files:
  - [none](/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_162504/benchmark_qwen35_35b_none_wrapper_10t.jsonl)
  - [small](/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_162504/benchmark_qwen35_35b_small_5k_wrapper_10t.jsonl)
  - [mid](/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_162504/benchmark_qwen35_35b_mid_20k_wrapper_10t.jsonl)
  - [long](/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_162504/benchmark_qwen35_35b_long_wrapper_10t.jsonl)
  - [longlong](/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_162504/benchmark_qwen35_35b_longlong_100k_wrapper_10t.jsonl)

### Active Wrapper Configuration

Important: the wrapper still launched the non-draft `SERVER_ARGS` path, not `SERVER_ARGS_DRAFT`, so this is a refreshed non-speculative baseline.

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Qwen3.5-35B-A3B-UD-Q8_K_XL.gguf \
  --alias qwen3.5-35b-a3b \
  --ctx-size 262144 \
  --temp 0.0 --top-p 1.0 --top-k 0 --min-p 0.0 \
  --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 1 \
  --mlock --no-mmap \
  --reasoning-format auto --reasoning-budget -1 \
  --n-predict 10000 \
  --jinja --reasoning off \
  --chat-template-kwargs '{"enable_thinking":false}' \
  --chat-template-file ~/llama.cpp/qwen3.5_chat_template.jinja
```

### Refreshed Results Summary

| Context | Prefill | TTFT | Throughput | Avg Prefill |
|---------|---------|------|------------|-------------|
| None (50 tok) | 0 | 0.36s | 39.0 tok/s | 0.00s |
| None (100 tok) | 0 | 0.45s | 35.4 tok/s | 0.00s |
| Small (15K) | 5K | 11.96s | 20.8 tok/s | 2.01s |
| Small (20K) | 5K | 18.81s | 16.6 tok/s | 1.03s |
| Mid (30K) | 20K | 14.74s | 17.4 tok/s | 6.08s |
| Mid (35K) | 20K | 21.70s | 14.0 tok/s | 1.21s |
| Long (50K) | 40K | 19.87s | 13.3 tok/s | 9.78s |
| Long (55K) | 40K | 31.65s | 10.2 tok/s | 1.72s |
| Longlong (110K) | 100K | 33.76s | 8.1 tok/s | 43.92s |
| Longlong (115K) | 100K | 49.21s | 6.9 tok/s | 2.76s |

### Old vs New

| Context | Old TTFT | New TTFT | Delta TTFT | Old tok/s | New tok/s | Delta tok/s |
|---------|----------|----------|------------|-----------|-----------|-------------|
| None (50 tok) | 0.33s | 0.36s | +0.03s | 28.7 | 39.0 | +10.3 |
| None (100 tok) | 0.43s | 0.45s | +0.02s | 31.0 | 35.4 | +4.4 |
| Small (15K) | 13.01s | 11.96s | -1.05s | 18.0 | 20.8 | +2.8 |
| Small (20K) | 21.73s | 18.81s | -2.93s | 13.7 | 16.6 | +2.9 |
| Mid (30K) | 16.71s | 14.74s | -1.97s | 14.8 | 17.4 | +2.6 |
| Mid (35K) | 25.73s | 21.70s | -4.03s | 11.7 | 14.0 | +2.3 |
| Long (50K) | 22.56s | 19.87s | -2.69s | 11.4 | 13.3 | +1.9 |
| Long (55K) | 31.51s | 31.65s | +0.14s | 10.1 | 10.2 | +0.0 |
| Longlong (110K) | 34.83s | 33.76s | -1.07s | 7.8 | 8.1 | +0.3 |
| Longlong (115K) | 54.02s | 49.21s | -4.81s | 6.5 | 6.9 | +0.5 |

### Notes

1. The refreshed wrapper is better almost everywhere, especially from 15K through 50K total context.
2. The biggest TTFT wins were at 20K, 35K, and 115K total context.
3. 55K total context is the outlier where TTFT stayed essentially unchanged.
4. None-context TTFT regressed slightly, but decode throughput improved sharply.
5. The full rerun completed with zero crashes and zero reloads.
