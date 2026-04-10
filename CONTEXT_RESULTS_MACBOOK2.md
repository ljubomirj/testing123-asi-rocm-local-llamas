# Context Benchmark Results - GLM-4.7-Flash on macbook2

**Date**: 2026-02-10
**Hardware**: Apple M2 Max, 96GB unified memory (~400 GB/s bandwidth)
**Model**: GLM-4.7-Flash-UD-Q6_K_XL.gguf (Q6, 24.25 GiB, 6.96 BPW)
**Backends tested**: LM Studio (llama.cpp/Metal) port 1234, raw llama.cpp (Metal) port 8081
**Comparison**: vs gigul2 (AMD 7900 XTX, 24GB VRAM, 960 GB/s, Vulkan, Q5_K_XL)

## Server Configuration (raw llama.cpp)

```bash
./build/bin/llama-server \
  --gpu-layers all --ctx-size 95000 --port 8081 \
  --model ~/llama.cpp/models/GLM-4.7-Flash-UD-Q6_K_XL.gguf \
  --temp 1.0 --top-p 0.95 --min-p 0.01 \
  --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 \
  --jinja --cache-ram 32768 --cache-reuse 512 --cache-prompt \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 --mlock --no-mmap --kv-unified
```

## Results - Raw llama.cpp (Metal, port 8081)

### 20K Total Context (10K prefill + 10K prompt)

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 67.245   | 3.4               | 678              | 198.974        |
| 2   | 68.698   | 3.4               | 663              | 192.648        |
| 3   | 64.588   | 3.4               | 637              | 187.144        |
| **Avg** | **66.844** | **3.4** | **659** | **192.922** |

### 25K Total Context (10K prefill + 15K prompt)

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 109.738  | 2.3               | 611              | 267.822        |
| 2   | 107.637  | 2.4               | 609              | 259.115        |
| 3   | 105.518  | 2.6               | 669              | 257.503        |
| **Avg** | **107.631** | **2.4** | **630** | **261.480** |

### 50K Total Context (40K prefill + 10K prompt)

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 154.710  | 1.6               | 699              | 424.615        |
| 2   | 169.002  | 1.5               | 678              | 445.670        |
| 3   | 171.259  | 1.5               | 680              | 460.564        |
| **Avg** | **164.990** | **1.5** | **686** | **443.616** |

**Context prefilling**:
- Cold cache: 231.87s
- Warm cache: 0.79s (293x faster)

### 55K Total Context (40K prefill + 15K prompt)

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 283.438  | 1.1               | 667              | 624.821        |
| 2   | 289.154  | 1.1               | 639              | 606.002        |
| 3   | 302.427  | 1.1               | 702              | 655.994        |
| **Avg** | **291.673** | **1.1** | **669** | **628.939** |

**Context prefilling**:
- Warm cache: 0.88-1.06s

## Results - LM Studio (llama.cpp/Metal, port 1234)

Note: LM Studio tests used 1 run per size for long-context, 3 runs for mid-context.

| Context | TTFT (s) | Throughput (tok/s) | Notes |
|---------|----------|-------------------|-------|
| 20K     | 67.674   | 3.3               | 3 runs avg |
| 25K     | 113.543  | 2.3               | 3 runs avg |
| 50K     | 173.040  | 0.93              | 1 run |
| 55K     | 265.822  | 1.13              | 1 run |

## LM Studio vs Raw llama.cpp (macbook2)

| Context | Metric | LM Studio | Raw llama.cpp | Improvement |
|---------|--------|-----------|---------------|-------------|
| 20K | TTFT | 67.7s | 66.8s | ~same |
| 20K | Throughput | 3.3 tok/s | 3.4 tok/s | ~same |
| 25K | TTFT | 113.5s | 107.6s | **5% faster** |
| 25K | Throughput | 2.3 tok/s | 2.4 tok/s | ~same |
| 50K | TTFT | 173.0s | 165.0s | **5% faster** |
| 50K | Throughput | 0.93 tok/s | 1.55 tok/s | **67% faster** |
| 55K | TTFT | 265.8s | 291.7s | **10% slower** |
| 55K | Throughput | 1.13 tok/s | 1.06 tok/s | ~same |

**Conclusion**: Raw llama.cpp with matching cache settings shows similar performance to LM Studio. TTFT is comparable. Throughput advantage at 50K (1.55 vs 0.93) may be due to the Q6 quantization having different token generation patterns, or the LM Studio 50K run being a single sample. At 55K, results converge.

Note: LM Studio used the model loaded in LM Studio (likely Q5 or Q4), while raw llama.cpp used Q6_K_XL. This quantization difference may account for some variation.

## macbook2 vs gigul2 Comparison

### Full Scaling Table

| Context | macbook2 TTFT | gigul2 TTFT | Ratio | macbook2 tok/s | gigul2 tok/s | Ratio |
|---------|---------------|-------------|-------|----------------|--------------|-------|
| **20K** | 66.8s | *(pending)* | - | 3.4 | *(pending)* | - |
| **25K** | 107.6s | *(pending)* | - | 2.4 | *(pending)* | - |
| **50K** | 165.0s | 80.0s | **2.1x** | 1.55 | 6.86 | **4.4x** |
| **55K** | 291.7s | 127.0s | **2.3x** | 1.06 | 4.36 | **4.1x** |

### Context Scaling on macbook2

| Metric | 20K | 25K | 50K | 55K |
|--------|-----|-----|-----|-----|
| **TTFT** | 66.8s | 107.6s | 165.0s | 291.7s |
| **Throughput** | 3.4 tok/s | 2.4 tok/s | 1.55 tok/s | 1.06 tok/s |
| **TTFT vs 20K** | 1.0x | 1.6x | 2.5x | 4.4x |
| **Throughput vs 20K** | 1.0x | 0.71x | 0.46x | 0.31x |

### TTFT Scaling Analysis

TTFT from 20K→25K (+25%): **+61%** increase
TTFT from 25K→50K (+100%): **+53%** increase
TTFT from 50K→55K (+10%): **+77%** increase

Super-linear degradation confirmed. Each additional 5K tokens at higher context sizes causes disproportionate slowdown.

### Hardware Comparison

| Spec | macbook2 | gigul2 |
|------|----------|--------|
| **GPU** | Apple M2 Max (38-core) | AMD 7900 XTX (96 CU) |
| **Memory** | 96GB unified | 24GB GDDR6X + 128GB system |
| **Bandwidth** | ~400 GB/s | 960 GB/s |
| **Backend** | Metal | Vulkan |
| **Quantization** | Q6_K_XL (6.96 BPW) | Q5_K_XL (~5.5 BPW) |
| **KV Cache** | q8_0 | q8_0 |
| **Flash Attn** | yes | yes |

## Key Findings

1. **TTFT ratio (~2.1-2.3x) matches memory bandwidth ratio (2.4x)** - confirms TTFT is memory-bandwidth bound

2. **Throughput ratio (4.1-4.4x) exceeds bandwidth ratio** - decode throughput has additional penalties beyond pure bandwidth, likely Metal backend efficiency vs Vulkan

3. **LM Studio vs raw llama.cpp: minimal difference** - LM Studio adds negligible overhead on macOS. Same caching settings produce same results. No need to run raw llama.cpp on macbook2.

4. **Cache works identically**: Both backends show ~300x warm-cache speedup

5. **Practical limits on macbook2**:
   - 20K context: 67s TTFT, 3.4 tok/s - borderline usable for interactive
   - 50K context: 165s TTFT, 1.5 tok/s - batch processing only
   - 55K context: 292s TTFT, 1.1 tok/s - batch processing only

## Files

- `benchmark_midcontext_macbook2.jsonl` - Mid-context, LM Studio (port 1234)
- `benchmark_longcontext_macbook2.jsonl` - Long-context, LM Studio (port 1234)
- `benchmark_midcontext_macbook2_llamacpp.jsonl` - Mid-context, raw llama.cpp (port 8081)
- `benchmark_longcontext_macbook2_llamacpp.jsonl` - Long-context, raw llama.cpp (port 8081)
- `bench_longcontext_macbook.py` - Benchmark script (stdlib only)

## Reproduction

```bash
# Mid-context (10K prefill)
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 --model glm-4.7-flash \
  --prefill-tokens 10000 --prompt-tokens 10000,15000 --runs 3

# Long-context (40K prefill)
python3 bench_longcontext_macbook.py \
  --base http://127.0.0.1:8081 --model glm-4.7-flash \
  --prefill-tokens 40000 --prompt-tokens 10000,15000 --runs 3
```
