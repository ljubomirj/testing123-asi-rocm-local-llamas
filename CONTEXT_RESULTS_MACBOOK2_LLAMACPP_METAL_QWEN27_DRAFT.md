# Qwen3.5-27B + 0.8B Draft (Speculative Decoding) Benchmark Results - macbook2

**Model**: Qwen3.5-27B-UD-Q8_K_XL.gguf (29GB) + Qwen3.5-0.8B-UD-Q8_K_XL.gguf draft (1.1GB)
**Hardware**: macbook2 (Apple M2 Max 96GB RAM, Metal backend)
**Software**: llama.cpp build 8494
**Test Date**: 2026-03-04

## Server Configuration

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --ctx-size 262144 \
  --host 127.0.0.1 \
  --port 8081 \
  --model models/Qwen3.5-27B-UD-Q8_K_XL.gguf \
  --model-draft models/Qwen3.5-0.8B-UD-Q8_K_XL.gguf \
  --draft-n 16 \
  --draft-p-min 0.9 \
  --draft-n-min 2 \
  --ctx-size-draft 2048 \
  --temp 1.0 \
  --top-p 0.95 \
  --min-p 0.01 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --cache-type-k-draft q8_0 \
  --cache-type-v-draft q8_0 \
  --jinja \
  --cache-ram 32768 \
  --cache-prompt \
  --parallel 1 \
  --batch-size 4096 \
  --ubatch-size 1024 \
  --threads-batch 10 \
  --threads 10 \
  --mlock \
  --no-mmap \
  --kv-unified \
  --split-mode none
```

---

## Results Summary

### None Context (No Prefill, Small Prompts)

| Context | TTFT  | Throughput |
|---------|-------|------------|
| 50      | 1.15s | 5.5 tok/s  |
| 100     | 1.81s | 6.2 tok/s  |

### Small Context (5K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~15K          | 62.16s  | 3.8 tok/s  |
| ~20K          | 95.57s  | 3.2 tok/s  |

### Mid Context (20K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~30K          | 74.03s  | 3.4 tok/s  |
| ~35K          | ~103s* | 2.8 tok/s  |

*Estimated from partial output

### Long Context (40K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~50K          | ~95s*   | ~3.0 tok/s* |
| ~55K          | ~120s*  | ~2.5 tok/s* |

*Estimated from pattern

### LongLong Context (100K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~110K         | 108.98s | 2.42 tok/s |
| ~115K         | 171.40s | 1.86 tok/s |

---

## Complete Results Table

┌─────────────────┬─────────┬──────────┬──────────┐
│     Context     │ Prefill │  TTFT    │ Thruput  │
├─────────────────┼─────────┼──────────┼──────────┤
│ None (50 tok)   │ 0       │ 1.15s    │ 5.5 t/s  │
│ None (100 tok)  │ 0       │ 1.81s    │ 6.2 t/s  │
├─────────────────┼─────────┼──────────┼──────────┤
│ Small (15K)     │ 5K      │ 62.16s   │ 3.8 t/s  │
│ Small (20K)     │ 5K      │ 95.57s   │ 3.2 t/s  │
├─────────────────┼─────────┼──────────┼──────────┤
│ Mid (30K)       │ 20K     │ 74.03s   │ 3.4 t/s  │
│ Mid (35K)       │ 20K     │ ~103s    │ 2.8 t/s  │
├─────────────────┼─────────┼──────────┼──────────┤
│ Long (50K)      │ 40K     │ ~95s     │ ~3.0 t/s │
│ Long (55K)      │ 40K     │ ~120s    │ ~2.5 t/s │
├─────────────────┼─────────┼──────────┼──────────┤
│ Longlong (110K) │ 100K    │ 108.98s  │ 2.42 t/s │
│ Longlong (115K) │ 100K    │ 171.40s  │ 1.86 t/s │
└─────────────────┴─────────┴──────────┴──────────┘

* = Estimated from partial output or pattern extrapolation

---

## Key Observations

1. **Speculative decoding impact**: The 0.8B draft model provides limited speedup compared to no-draft results
   - Baseline: ~6 tok/s (no prefill)
   - With draft: ~6 tok/s (minimal difference)

2. **Cache effectiveness**: Context prefill shows significant speedup on subsequent runs
   - First run 20K prefill: 86.17s
   - Cached runs: ~5-6s

3. **Memory usage**: With 32GB cache-ram, the system has plenty of headroom on 96GB RAM
   - Model: 29GB + 1.1GB = ~30GB
   - KV cache at 100K context: significant but manageable

4. **Practical context limit**: 115K works well with the draft model

---

## Comparison: Draft vs No Draft

| Metric | 27B + Draft | 27B No Draft (previous) |
|--------|-------------|-------------------------|
| Baseline (50 tok) | 5.5 tok/s | 6.8 tok/s |
| 15K TTFT | 62s | 62s |
| 30K TTFT | 74s | 77s |
| 110K TTFT | 109s | 119s |

**Note**: Speculative decoding shows minimal improvement for this model pair. The 0.8B draft model may be too small compared to the 27B main model for optimal speculation.
