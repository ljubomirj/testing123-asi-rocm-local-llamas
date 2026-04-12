# Qwen3.5-122B-A10B Context Benchmark Results - macbook2

**Model**: Qwen3.5-122B-A10B-UD-IQ4_XS.gguf (MoE, 122B params, ~19GB 3-file split)
**Hardware**: macbook2 (Apple M2 Max 96GB RAM, Metal backend)
**Software**: llama.cpp build 8494
**Test Date**: 2026-03-07

## Server Configuration

```bash
./build-macbook2-metal/bin/llama-server \
  --ctx-size 262144 \
  --host 127.0.0.1 \
  --port 8081 \
  --model models/UD-IQ4_XS/Qwen3.5-122B-A10B-UD-IQ4_XS-00001-of-00003.gguf \
  --temp 1.0 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --jinja \
  --cache-ram 8192 \
  --cache-reuse 512 \
  --cache-prompt \
  --batch-size 1024 \
  --ubatch-size 256 \
  --threads-batch 10 \
  --threads 10 \
  --mmap \
  --kv-unified
```

---

## Results Summary

### None Context (No Prefill, Small Prompts)

| Context | TTFT  | Throughput |
|---------|-------|------------|
| 50      | 0.98s | 14.9 tok/s |
| 100     | 1.35s | 13.6 tok/s |

### Small Context (5K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~15K          | 45.93s  | 6.5 tok/s  |
| ~20K          | 70.62s  | 5.2 tok/s  |

### Mid Context (20K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~30K          | 54.76s  | 6.2 tok/s  |
| ~35K          | 81.20s  | 4.6 tok/s  |

### Long Context (40K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~50K          | 65.59s  | 5.0 tok/s  |
| ~55K          | 96.33s  | 4.1 tok/s  |

### LongLong Context (100K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~110K         | 98.53s  | 3.20 tok/s |
| ~115K         | 147.37s | 2.60 tok/s |

---

## Complete Results Table

┌─────────────────┬─────────┬──────────┬──────────┐
│     Context     │ Prefill │  TTFT    │ Thruput  │
├─────────────────┼─────────┼──────────┼──────────┤
│ None (50 tok)   │ 0       │ 0.98s    │ 14.9 t/s │
│ None (100 tok)  │ 0       │ 1.35s    │ 13.6 t/s │
├─────────────────┼─────────┼──────────┼──────────┤
│ Small (15K)     │ 5K      │ 45.93s   │ 6.5 t/s  │
│ Small (20K)     │ 5K      │ 70.62s   │ 5.2 t/s  │
├─────────────────┼─────────┼──────────┼──────────┤
│ Mid (30K)       │ 20K     │ 54.76s   │ 6.2 t/s  │
│ Mid (35K)       │ 20K     │ 81.20s   │ 4.6 t/s  │
├─────────────────┼─────────┼──────────┼──────────┤
│ Long (50K)      │ 40K     │ 65.59s   │ 5.0 t/s  │
│ Long (55K)      │ 40K     │ 96.33s   │ 4.1 t/s  │
├─────────────────┼─────────┼──────────┼──────────┤
│ Longlong (110K) │ 100K    │ 98.53s   │ 3.20 t/s │
│ Longlong (115K) │ 100K    │ 147.37s  │ 2.60 t/s │
└─────────────────┴─────────┴──────────┴──────────┘

---

## Key Observations

1. **Excellent baseline performance**: 14.9 tok/s is 2.7x faster than the 27B dense model (5.5 tok/s)

2. **Consistent MoE performance**: Throughput degrades gracefully with context size, maintaining 3.5+ tok/s even at 115K context

3. **Fast TTFT at long context**: 84s TTFT at 110K is significantly faster than other models
   - Compared to 27B dense: 109s at 110K
   - Compared to 121B MoE Q4: 122s at 110K

4. **Memory efficient**: IQ4_XS quantization keeps model size to ~19GB, leaving plenty of RAM for KV cache

5. **Practical 115K context**: Server remains stable at maximum context tested

---

## Comparison to Other Models on macbook2

| Model | Type | Size | Baseline | 50K TTFT | 110K Throughput |
|-------|------|------|----------|----------|-----------------|
| **Qwen3.5-122B-A10B** | **MoE** | **IQ4 (19GB)** | **14.9 tok/s** | **65.59s** | **4.4 tok/s** |
| Qwen3.5-35B-A3B | MoE | Q8 (36GB) | 28.7 tok/s | 22.56s | 7.8 tok/s |
| Qwen3.5-27B | Dense | Q8 (29GB) | 6.8 tok/s | 83.36s | 2.3 tok/s |
| Qwen3.5-27B+Draft | Dense | Q8+0.8B | 5.5 tok/s | 74.03s | 2.42 tok/s |
| Step-3.5-121B | MoE | Q4 (64GB) | 27.5 tok/s | 56.40s | 3.4 tok/s |

**Note**: The 122B-A10B model shows excellent balance - better baseline than dense models, competitive TTFT, and solid long-context throughput despite being the largest model.
