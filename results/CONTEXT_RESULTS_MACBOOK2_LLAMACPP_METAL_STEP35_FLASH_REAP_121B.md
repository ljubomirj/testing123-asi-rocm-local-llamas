# Step-3.5-Flash-REAP-121B-A11B Context Benchmark Results - macbook2

**Model**: Step-3.5-Flash-REAP-121B-A11B.Q4_K_S.gguf (MoE, 121B params, ~64GB)
**Hardware**: macbook2 (Apple M2 Max 96GB RAM, Metal backend)
**Software**: llama.cpp build 8466
**Test Date**: 2026-03-03

## Server Configuration

```
~/llama.cpp/build/bin/llama-server \
  --ctx-size 131072 \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Step-3.5-Flash-REAP-121B-A11B.Q4_K_S.gguf \
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

---

## Results Summary

### None Context (No Prefill, Small Prompts)

| Context | TTFT  | Throughput |
|---------|-------|------------|
| 50      | 0.72s | 27.5 tok/s |
| 100     | 1.07s | 24.2 tok/s |

### Small Context (5K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~15K          | 40.71s  | 9.6 tok/s  |
| ~20K          | 58.33s  | 7.4 tok/s  |

### Mid Context (20K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~30K          | 46.04s  | 8.5 tok/s  |
| ~35K          | 70.61s  | 6.5 tok/s  |

### Long Context (40K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~50K          | 56.40s  | 7.6 tok/s  |
| ~55K          | 89.83s  | 5.3 tok/s  |

### LongLong Context (100K Prefill + 10K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~110K         | 122.03s | 3.4 tok/s  |

**Note**: Server became unstable at 115K context (connection refused). Only one successful 110K run was completed before crash.

---

## Key Observations

1. **121B model is slower than smaller MoE models**: Baseline 27.5 tok/s vs 28.7 tok/s (35B-A3B Q8) - surprisingly close

2. **TTFT grows significantly with model size**: 56s at 50K context vs 22.6s for 35B-A3B Q8

3. **Memory pressure at large context**: 64GB model + 100K context KV cache = near 96GB RAM limit, causing instability

4. **Throughput degradation**: Decode throughput drops from ~27 tok/s baseline to ~3.4 tok/s at 110K context

5. **Practical limit**: 110K context appears to be the maximum stable size for this 121B model on 96GB RAM

---

## Comparison to Other Models on macbook2

| Model | Type | Size | Baseline | 50K TTFT | 110K Throughput |
|-------|------|------|----------|----------|-----------------|
| Step-3.5-Flash-REAP-121B | MoE | Q4_K_S (64GB) | 27.5 tok/s | 56.40s | 3.4 tok/s |
| Qwen3.5-35B-A3B | MoE | Q8_K_XL (36GB) | 28.7 tok/s | 22.56s | 7.8 tok/s |
| Qwen3.5-27B | Dense | Q8_K_XL (29GB) | 6.8 tok/s | 83.36s | 2.3 tok/s |
| GLM-4.7-Flash | MoE | Q4_K_XL (17GB) | 0.93 tok/s | 173s | N/A |

**Conclusion**: The 121B MoE model offers competitive baseline performance but suffers from higher TTFT and memory pressure at long context. The 35B-A3B MoE Q8 provides better performance across all metrics on 96GB RAM.
