# Qwen3.6-35B-A3B-4bit MLX LLAMA-BENCH Style Results - macbook2

**Date**: 2026-04-19

**Model**: `mlx-community/Qwen3.6-35B-A3B-4bit` (MLX 4-bit quantization)

**Hardware**: `macbook2` (Apple M2 Max, 96 GB RAM, Metal backend via MLX)

**Server**: `mlx_lm.server` with thinking ON (5000 budget), prompt cache enabled

## Server Configuration

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

## Results Summary

| PP | TG | TTFT | PP t/s | TG t/s |
|---:|---:|--------|--------|--------|
| 256 | 512 | 5.78s | 44.6 | 68.4 |
| 512 | 512 | 6.88s | 75.2 | 54.3 |
| 1024 | 512 | 7.37s | 142.8 | 49.5 |
| 1024 | 1024 | 6.89s | 148.7 | 51.6 |
| 2048 | 512 | 10.86s | 202.7 | 40.2 |
| 2048 | 1024 | 9.60s | 213.4 | 42.3 |
| 4096 | 512 | 26.25s | 156.0 | 16.0 |
| 4096 | 1024 | 9.94s | 412.0 | 42.2 |
| 8192 | 512 | 35.51s | 230.7 | 11.3 |

## Key Observations

1. **Strong prompt cache effect**: Second runs are often faster (TTFT and PP speed benefit)
2. **Good short-context performance**: 44-75 t/s PP, 54-68 t/s TG for ≤512 tokens
3. **Excellent PP speed at 1024+**: 140-213 t/s (cache optimized)
4. **TG speed drops with long contexts**: 11-16 t/s at 4096+ context
5. **8192 context slow**: PP 230 t/s but TG only 11.3 t/s (thinking dominates)

## Comparison to llama.cpp Q6_K_XL

| PP | TG | MLX TG t/s | Q6_K_XL TG t/s | Ratio |
|---:|---:|---:|---:|---:|
| 256 | 512 | 68.4 | 42.3 | 1.6× MLX |
| 512 | 512 | 54.3 | 39.2 | 1.4× MLX |
| 1024 | 512 | 49.5 | 37.6 | 1.3× MLX |
| 1024 | 1024 | 51.6 | 36.5 | 1.4× MLX |
| 2048 | 512 | 40.2 | 38.0 | 1.1× MLX |
| 2048 | 1024 | 42.3 | 38.0 | 1.1× MLX |
| 4096 | 512 | 16.0 | 34.1 | 0.5× llama.cpp |
| 8192 | 512 | 11.3 | 28.2 | 0.4× llama.cpp |

**Analysis**:
- MLX with 4-bit + prompt cache is **faster at short contexts** (1.1-1.6× TG speed)
- llama.cpp Q6_K_XL is **faster at long contexts** (better memory management for large contexts)
- The crossover appears around 2048-4096 tokens
- At 8192, MLX drops significantly (likely memory/attention patterns)

## Notes

- All tests with thinking ON (5000 token budget)
- Prompt cache (12GB) provides significant speedup for repeated prompts
- Results show high variance - caching behavior has major impact
- TTFT includes thinking time for Qwen3.6 models

## Raw Data

Log file: `runs/mlx_qwen36_llamabench_20260419_230509.log`
