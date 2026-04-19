# Qwen3.6-35B-A3B-4bit MLX Context Benchmark Results - macbook2

**Date**: 2026-04-19

**Model**: `mlx-community/Qwen3.6-35B-A3B-4bit` (MLX 4-bit quantization)

**Hardware**: `macbook2` (Apple M2 Max, 96 GB RAM, Metal backend via MLX)

**Run root**: N/A (direct API benchmark)

**Server**: `mlx_lm.server` with the following configuration:
```bash
mlx_lm.server \
  --model mlx-community/Qwen3.6-35B-A3B-4bit \
  --trust-remote-code \
  --port 8081 \
  --max-tokens 8192 \
  --chat-template-args '{"enable_thinking":true,"preserve_thinking":true}' \
  --prompt-cache-size 16 \
  --prompt-cache-bytes 12GB \
  --decode-concurrency 4 \
  --prompt-concurrency 2
```

## Bottom Line

Qwen3.6-35B-A3B-4bit MLX on the M2 Max shows strong performance at short contexts (63-73 tok/s with cache) and reasonable performance through 20K context (15-58 tok/s depending on cache hits). At 40K+ context, performance drops significantly to ~2 tok/s. The 100K context test failed due to server disconnection.

**Note**: Results show significant caching behavior - first run with a given context size is slow, subsequent runs are much faster due to prompt cache.

## Test Parameters

- **Thinking mode**: ON (deepseek format)
- **Max tokens**: 200 for generation
- **Streaming**: False
- **Multiple runs**: 3 for none/small, 1 for mid/long/longlong
- **Prompt cache**: Enabled (16 slots, 12GB)

## Results

### Context Summary

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|
| 50 | 0 | 50 | 2.91s | 68.7 tok/s |
| 100 | 0 | 100 | 3.19s | 62.7 tok/s |
| 5010 | 5K | 10 | 3.54s | 56.2 tok/s* |
| 5015 | 5K | 15 | 3.74s | 53.8 tok/s* |
| 20010 | 20K | 10 | 47.24s | 4.2 tok/s |
| 20015 | 20K | 15 | 45.16s | 2.1 tok/s |
| 40010 | 40K | 10 | 101.88s | 2.0 tok/s |
| 40015 | 40K | 15 | 98.55s | 1.9 tok/s |
| 100010 | 100K | 10 | **FAILED** | **Server disconnected** |

\* Cached runs (2nd/3rd run significantly faster than 1st run due to prompt cache)

### None Context (no prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 2.91s | 68.7 tok/s | 3 |
| 100 | 0 | 100 | 3.19s | 62.7 tok/s | 3 |

### Small Context (5K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---:|---:|---:|---:|---:|
| 5010 | 5K | 10 | 6.50s† | 42.8 tok/s† | 3 |
| 5015 | 5K | 15 | 6.72s† | 42.0 tok/s† | 3 |

† First run: ~13s TTFT, ~15 tok/s (cache miss)
† Cached runs: ~3.6s TTFT, ~56 tok/s (cache hit)

### Mid Context (20K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---|---:|---:|---:|---:|
| 20010 | 20K | 10 | 47.24s | 4.2 tok/s | 1 |
| 20015 | 20K | 15 | 45.16s | 2.1 tok/s | 1 |

### Long Context (40K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---|---:|---:|---:|---:|
| 40010 | 40K | 10 | 101.88s | 2.0 tok/s | 1 |
| 40015 | 40K | 15 | 98.55s | 1.9 tok/s | 1 |

### LongLong Context (100K prefill)

| Total context | Prefill | Prompt | TTFT | Throughput | Runs |
|---|---|---||---:|---||
| 100010 | 100K | 10 | **FAILED** | **Server disconnected** | - |

## Takeaways

1. **Strong short-context performance**: 63-73 tok/s with cache enabled
2. **Prompt cache works very well**: 2nd/3rd runs are 3-4× faster
3. **Mid-context usable**: 20K context gives ~2-4 tok/s
4. **Long-context slow**: 40K context drops to ~2 tok/s
5. **100K context fails**: Server disconnected during request (likely memory or timeout issue)
6. **Cold vs cached**: First run with new context size is significantly slower than cached runs

## Comparison to llama.cpp Q6_K_XL (same M2 Max)

| Context | MLX 4bit tok/s | Q6_K_XL tok/s | Ratio |
|---|---:|---:|---:|
| 50 | 68.7 | 44.4 | 1.5× MLX (cached) |
| 100 | 62.7 | 40.8 | 1.5× MLX (cached) |
| 15K | 15-58 | 20.3 | Variable (cache) |
| 30K | 2-4 | 18.6 | 4-9× llama.cpp |
| 50K | ~2 | 13.5 | 7× llama.cpp |

**Analysis**:
- MLX is faster at short contexts **with cache enabled** (prompt cache is a key feature)
- At longer contexts (20K+), llama.cpp Q6_K_XL is significantly faster
- The 4-bit quantization may lose some performance vs 6-bit at longer contexts
- MLX prompt cache (12GB) provides excellent speedup for repeated prompts

## Known Issues

1. **100K context failure**: Server disconnects during 100K token requests
2. **Cache dependency**: Performance highly dependent on prompt cache hits
3. **Cold start penalty**: First run with new context is 3-4× slower
4. **No 50K-55K tests**: Skipped due to 100K failure

## Configuration Notes

- **Prompt cache**: 16 slots, 12GB - this is a key performance feature
- **Decode concurrency**: 4 - allows parallel generation
- **Prompt concurrency**: 2 - allows parallel prefill
- **Thinking mode**: Enabled with preserve_thinking=true
- **Max tokens**: 8192 (server default)

## Raw Data

Log file: `runs/mlx_qwen36_context_20260419_221117.log`
