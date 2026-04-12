# Qwen3.5-27B Dense Context Benchmark Results - macbook2

**Model**: Qwen3.5-27B-UD-Q8_K_XL.gguf (Dense, 27B params, ~29GB)
**Hardware**: macbook2 (Apple M2 Max 96GB RAM, Metal backend)
**Software**: llama.cpp build 8466
**Test Date**: 2026-03-01

## Server Configuration

```
~/llama.cpp/build/bin/llama-server \
  --ctx-size 131072 \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Qwen3.5-27B-UD-Q8_K_XL.gguf \
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
| 50      | 0.90s | 6.8 tok/s  |
| 100     | 1.55s | 5.9 tok/s  |

### Small Context (5K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~15K          | 61.86s  | 3.9 tok/s  |
| ~20K          | 106.01s | 2.7 tok/s  |

### Mid Context (20K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~30K          | 77.45s  | 3.3 tok/s  |
| ~35K          | 114.52s | 2.7 tok/s  |

### Long Context (40K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~50K          | 83.36s  | 3.1 tok/s  |
| ~55K          | 129.27s | 2.4 tok/s  |

### LongLong Context (100K Prefill + 10K/15K Prompt)

| Total Context | TTFT    | Throughput |
|---------------|---------|------------|
| ~110K         | 118.62s | 2.3 tok/s  |
| ~115K         | 160.14s | 2.0 tok/s  |

---

## Key Observations

1. **Dense model is ~4-5x slower than MoE**: Baseline 6.8 tok/s vs 28.7 tok/s (35B-A3B MoE Q8)

2. **TTFT scales with context size**: From 0.9s at 50 tokens to 160s at 115K tokens

3. **Throughput degradation**: Decode throughput drops from ~6 tok/s at small context to ~2 tok/s at 115K

4. **Cache effectiveness**: Context prefill warm cache is ~5-10x faster than cold (e.g., 100K: 8-10s vs 457s)

5. **Practical limit**: At 115K context, 2 tok/s means a 512-token response takes ~4 minutes

---

## Comparison to Other Models on macbook2

| Model | Type | Size | Baseline | 50K TTFT | 115K Throughput |
|-------|------|------|----------|----------|-----------------|
| Qwen3.5-27B | Dense | Q8 (29GB) | 6.8 tok/s | 83.36s | 2.0 tok/s |
| Qwen3.5-35B-A3B | MoE | Q8 (36GB) | 28.7 tok/s | 22.56s | 6.5 tok/s |
| Qwen3.5-27B | Dense | Q5 (19GB) | 27.8 tok/s | 43.0 tok/s | 4.4 tok/s |
| GLM-4.7-Flash | MoE | Q4 (17GB) | 0.93 tok/s | 173s | 1.13 tok/s |

**Conclusion**: The dense 27B model at Q8 is not competitive. The MoE architecture provides ~4x better performance despite being a larger model. Use Q5 quantization for dense models if MoE is unavailable.
