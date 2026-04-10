# Testing Guide - SGLang ROCm Performance

## Quick Start

### 1. Start SGLang Server (ROCm Branch)
```bash
# From project root
./run_sglang_8081.sh
```

Server will start on port 8081. Wait for "Application startup complete" message.

### 2. Run Benchmarks

**Quick test (3 runs, default prompt lengths):**
```bash
python3 bench_comprehensive.py
```

**Custom configuration:**
```bash
# Test specific prompt lengths with more runs
python3 bench_comprehensive.py \
  --prompt-lengths 1000,5000,10000,20000,50000 \
  --runs 5 \
  --max-tokens 4096 \
  --output results_test1.jsonl
```

**Verbose output:**
```bash
# -v shows responses, -vv shows prompts too
python3 bench_comprehensive.py -v --runs 2
```

### 3. Test Prefix Caching

Run multiple iterations with the **same system prompt** to test cache effectiveness:
```bash
python3 bench_comprehensive.py --runs 5 --prompt-lengths 10000
```

Expected: Run 2+ should show:
- Lower TTFT (cached system prompt)
- Higher cache_hit_rate
- More cached_tokens

## Metrics Explained

### Performance Metrics
- **TTFT (Time To First Token)**: Latency until first response character arrives
  - Lower is better
  - Affected by prompt length and cache hits
  - Target: <1s for 10K prompts with caching

- **Throughput (chars/sec)**: Generation speed
  - Higher is better
  - Compare with llama.cpp baseline (~10 tokens/sec ≈ 40-50 chars/sec)
  - ROCm optimizations should improve this

- **Cache Hit Rate**: Percentage of prompt tokens served from cache
  - 0.0-1.0 (0%-100%)
  - Higher means better prefix reuse
  - Significant TTFT improvement when >0.5

### Resource Metrics
- **GPU VRAM**: Memory usage on 7900 XTX (24GB total)
  - Monitor for OOM issues
  - Higher context = more VRAM

- **Cached Tokens**: Total tokens in cache (cumulative)
- **Prompt Tokens**: Total input tokens processed
- **Generation Tokens**: Total output tokens generated

## Comparing Results

### SGLang vs llama.cpp
```bash
# SGLang (this setup)
python3 bench_comprehensive.py --base http://192.168.1.251:8081

# llama.cpp (if running on different port)
# Note: llama.cpp uses different API, manual comparison needed
```

Llama.cpp baseline (from notes):
- ~10 tokens/sec with long context
- No structured metrics endpoint
- Different quantization (Q5_K_XL vs AWQ)

### Main vs ROCm Branch
To compare branches, you'd need to:
1. Start server from `sglang-src/` (main branch) on port 8000
2. Start server from `sglang-rocm-branch/` (PR branch) on port 8081
3. Run benchmarks against both

## Output Format

Results saved to JSONL (one JSON object per line):
```json
{
  "run_id": 1,
  "prompt_length": 10000,
  "max_tokens": 2048,
  "ttft_sec": 0.456,
  "chars_per_sec": 89.2,
  "total_chars": 512,
  "total_time_sec": 5.74,
  "cache_hit_rate": 0.75,
  "gpu_vram_used_mb": 8192.0,
  "gpu_vram_total_mb": 24576.0,
  "cached_tokens": 5000,
  "prompt_tokens": 15000,
  "generation_tokens": 3000
}
```

Load and analyze with:
```python
import json
import pandas as pd

results = []
with open('benchmark_results.jsonl') as f:
    for line in f:
        results.append(json.loads(line))
df = pd.DataFrame(results)
print(df.groupby('prompt_length')[['ttft_sec', 'chars_per_sec', 'cache_hit_rate']].mean())
```

## Troubleshooting

### Server won't start
- Check GPU is free: `rocm-smi`
- Check port is available: `lsof -i :8081`
- Check ROCm installation: `ls /opt/rocm-7.1.1`

### Metrics not available
- Verify /metrics endpoint: `curl http://192.168.1.251:8081/metrics`
- Some metrics (cache_hit_rate) may be 0.0 on first run

### GPU memory issues
- Reduce `--max-total-tokens` in startup script
- Reduce `--mem-fraction-static` (currently 0.85)
- Monitor with: `watch -n 1 rocm-smi`

## Advanced Testing

### Long context testing
```bash
# Test up to 32K context (server max)
python3 bench_comprehensive.py \
  --prompt-lengths 5000,10000,20000,30000 \
  --max-tokens 2048 \
  --runs 3
```

### Stress testing cache
```bash
# Many runs to populate cache
python3 bench_comprehensive.py \
  --prompt-lengths 10000 \
  --runs 10 \
  --output cache_test.jsonl

# Analyze cache warming:
# Run 1: cold (low cache hit)
# Run 2+: warm (high cache hit, lower TTFT)
```

### Memory profiling
```bash
# Monitor VRAM during benchmark
watch -n 0.5 rocm-smi &
WATCH_PID=$!
python3 bench_comprehensive.py --prompt-lengths 20000 --runs 5
kill $WATCH_PID
```
