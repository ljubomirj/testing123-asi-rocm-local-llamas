# Qwen3.6-35B-A3B Q6_K_XL llama-bench Style Results - macbook2

**Date**: 2026-04-17

**Model**: `Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf` (31GB)

**Hardware**: `macbook2` (Apple M2 Max, 96 GB RAM, Metal)

**Server Parameters**:
- Reasoning: ON (deepseek format, 5000 token budget)
- Context: 150000
- Flash attention: ON
- KV cache: q8_0
- Threads: 8
- Batch/ubatch: 2048/512

## Results Summary

### PP/TG Matrix (Streaming)

| PP | TG | TTFT | PP Speed* | TG Speed |
|---:|---:|---:|---:|---:|
| 256 | 512 | 9.86s | 26.0 t/s | 42.3 t/s |
| 512 | 512 | 13.08s | 39.1 t/s | 39.2 t/s |
| 1024 | 512 | 11.54s | 88.7 t/s | 37.6 t/s |
| 1024 | 1024 | 11.57s | 88.5 t/s | 36.5 t/s |
| 2048 | 512 | 14.76s | 138.8 t/s | 32.7 t/s |
| 2048 | 1024 | 14.77s | 138.7 t/s | 38.0 t/s |
| 4096 | 512 | 15.17s | 273.7 t/s | 37.2 t/s |
| 4096 | 1024 | 13.55s | 302.3 t/s | 34.1 t/s |
| 8192 | 1024 | 22.92s | 357.5 t/s | 28.2 t/s |

*PP Speed is calculated as PP/TTFT, which includes thinking time. Actual prompt processing is much faster.

## Key Observations

1. **TTFT includes thinking**: The high TTFT (9-23s) includes the ~5000 token reasoning phase. The actual prompt processing is much faster (likely 1000-2000+ t/s based on CONTEXT tests).

2. **Consistent TG speed**: After thinking completes, text generation is stable at **~28-42 t/s** regardless of context size.

3. **Larger PP = slower TTFT**: As prompt size increases, TTFT increases due to:
   - More tokens to process
   - More context for thinking to consider
   - Potential cache misses

4. **Thinking dominates latency**: With 5000 token reasoning budget, TTFT is dominated by thinking time rather than prompt processing.

## Interpretation

### Effective Prompt Processing Speed
Based on CONTEXT test results (no thinking), actual PP speed is:
- Small prompts (50-100 tokens): **~2000-2500 t/s**
- Medium prompts (512-1024 tokens): **~1500-2200 t/s**
- Large prompts (4096+ tokens): **~700-1800 t/s**

### Text Generation Speed
- **With thinking ON**: ~28-42 t/s (after thinking completes)
- **Without thinking** (from CONTEXT): ~11-44 t/s depending on context

## Comparison to Standard llama-bench

Standard llama-bench tests models **without thinking/reasoning**. These results include:
- Reasoning phase (~5000 tokens)
- Response generation

The TTFT here is NOT comparable to standard llama-bench TTFT because it includes thinking time.

To compare with standard benchmarks:
- **TG speed** (~35 t/s) IS comparable
- **PP speed** is NOT directly comparable due to thinking overhead

## Raw Data

- `bench_stream_results.json` - Full results
- `bench_stream_output.log` - Test output

## Notes

- Tests run against running server on port 8081
- 2 runs per PP/TG combination
- Streaming mode for accurate TTFT measurement
- Model uses thinking mode with 5000 token reasoning budget

---

## ngram-draft Results (2026-04-17 13:22)

**Additional server parameters**:
- `--spec-type ngram-mod --spec-ngram-size-n 24 --draft-min 48 --draft-max 64`
- `--mmap` (was `--no-mmap`)
- Refreshed binary build

### PP/TG Matrix (ngram-draft)

| PP | TG | TTFT | PP t/s* | TG t/s |
|---:|---:|---:|---:|---:|
| 256 | 512 | 9.74s | 26.3 | 41.4 |
| 512 | 512 | 13.49s | 38.0 | 37.0 |
| 1024 | 512 | 13.73s | 74.6 | 31.2 |
| 1024 | 1024 | 12.81s | 80.0 | 33.7 |
| 2048 | 512 | 15.59s | 131.4 | 32.0 |
| 2048 | 1024 | 15.26s | 134.2 | 36.6 |
| 4096 | 512 | 16.73s | 245.5 | 36.6 |
| 4096 | 1024 | 13.26s | 309.0 | 35.3 |
| 8192 | 1024 | 22.04s | 371.7 | 29.5 |

*PP speed includes thinking time

### Comparison: Non-draft vs ngram-draft

| PP | TG | Non-Draft TTFT | Draft TTFT | Non-Draft TG | Draft TG |
|---:|---:|---:|---:|---:|---:|
| 256 | 512 | - | 9.74s | - | 41.4 |
| 512 | 512 | - | 13.49s | - | 37.0 |
| 1024 | 1024 | - | 12.81s | - | 33.7 |
| 2048 | 1024 | - | 15.26s | - | 36.6 |
| 4096 | 1024 | - | 13.26s | - | 35.3 |

**Observation**: ngram-draft shows minimal speedup in this configuration. The thinking budget (5000 tokens) dominates TTFT, masking any speculative decoding benefits.
