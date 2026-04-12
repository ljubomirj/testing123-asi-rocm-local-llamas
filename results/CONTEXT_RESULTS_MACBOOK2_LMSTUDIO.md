# Long-Context Benchmark Results - GLM-4.7-Flash on macbook2

**Date**: 2026-02-10
**Model**: GLM-4.7-Flash (via LM Studio, llama.cpp backend)
**Hardware**: Apple M2 Max, 96GB unified memory
**Server**: LM Studio (llama.cpp) on localhost:1234
**Comparison**: vs gigul2 (AMD Radeon RX 7900 XTX, 24GB VRAM, Vulkan)

## Test Configuration

### Server:
- LM Studio server on port 1234
- Model: glm-4.7-flash (GGUF quantization loaded by LM Studio)
- Backend: llama.cpp (Metal)

### Benchmark Parameters (identical to gigul2):
- **Context prefill**: 40,000 tokens (~160KB coherent text)
- **Prompt sizes**: 10,000 and 15,000 tokens (~40KB and 60KB)
- **Runs per size**: 1
- **Max generation**: 512 tokens per request
- **Total active context**: 50K-55K tokens

## Results

### 50K Total Context (40K prefill + 10K prompt)

| Metric | macbook2 (M2 Max) | gigul2 (7900 XTX) | Ratio |
|--------|-------------------|-------------------|-------|
| **TTFT** | 173.040s | 79.998s | **2.2x slower** |
| **Throughput** | 0.93 tok/s | 6.86 tok/s | **7.4x slower** |
| **Generated Tokens** | 252 | 682 (avg) | - |
| **Total Time** | 271.800s | 99.444s | **2.7x slower** |

**Context prefilling**:
- Cold cache: 265.43s (gigul2: 125.25s, **2.1x slower**)

### 55K Total Context (40K prefill + 15K prompt)

| Metric | macbook2 (M2 Max) | gigul2 (7900 XTX) | Ratio |
|--------|-------------------|-------------------|-------|
| **TTFT** | 265.822s | 127.016s | **2.1x slower** |
| **Throughput** | 1.13 tok/s | 4.36 tok/s | **3.9x slower** |
| **Generated Tokens** | 652 | 645 (avg) | ~same |
| **Total Time** | 578.900s | 148.146s | **3.9x slower** |

**Context prefilling**:
- Warm cache: 1.04s (gigul2: 0.38s, **2.7x slower**)

### 20K Total Context (10K prefill + 10K prompt) - Mid-Context

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 67.106   | 3.2               | 635              | 201.274        |
| 2   | 67.065   | 3.3               | 638              | 192.889        |
| 3   | 68.852   | 3.3               | 658              | 196.637        |
| **Avg** | **67.674** | **3.3** | **644** | **196.933** |

### 25K Total Context (10K prefill + 15K prompt) - Mid-Context

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 108.922  | 2.2               | 573              | 266.193        |
| 2   | 116.513  | 2.5               | 664              | 269.038        |
| 3   | 115.195  | 2.3               | 623              | 269.354        |
| **Avg** | **113.543** | **2.3** | **620** | **268.195** |

## Performance Analysis

### Memory Bandwidth Comparison

| Spec | macbook2 (M2 Max) | gigul2 (7900 XTX) | Ratio |
|------|-------------------|-------------------|-------|
| **Memory Bandwidth** | ~400 GB/s | 960 GB/s | 2.4x |
| **VRAM/Memory** | 96GB unified | 24GB dedicated | - |
| **Architecture** | Apple Silicon (Metal) | RDNA 3 (Vulkan) | - |

### Observed vs Expected Scaling

| Metric | Expected (bandwidth ratio) | Observed | Notes |
|--------|---------------------------|----------|-------|
| **TTFT** | ~2.4x slower | 2.1-2.2x slower | Better than expected! |
| **Throughput** | ~2.4x slower | 3.9-7.4x slower | Worse than expected |
| **Prefill (cold)** | ~2.4x slower | 2.1x slower | Matches bandwidth |
| **Prefill (warm)** | ~2.4x slower | 2.7x slower | Close to expected |

### Key Observations

1. **TTFT scales with memory bandwidth**: The 2.1-2.2x TTFT ratio closely matches the memory bandwidth ratio (400 vs 960 GB/s = 2.4x). TTFT is dominated by prompt processing which is memory-bandwidth bound.

2. **Throughput is worse than expected**: The 3.9-7.4x throughput penalty exceeds the bandwidth ratio. Possible causes:
   - Metal backend may be less optimized than Vulkan for this model
   - LM Studio overhead vs raw llama.cpp
   - Different KV cache quantization/settings
   - M2 Max GPU may have fewer compute units optimized for transformer ops
   - The gigul2 used specific optimizations (flash-attn, q8_0 KV cache, mlock, etc.)

3. **Cache effectiveness preserved**: Both machines show dramatic warm-cache speedup:
   - macbook2: 265.43s → 1.04s (255x)
   - gigul2: 125.25s → 0.35s (357x)

4. **Token generation difference at 50K**: macbook2 generated only 252 tokens vs 682 on gigul2 at 50K context. At 55K context, token counts were comparable (652 vs 645). This may indicate different reasoning depth or streaming behavior.

### Actual Generation Throughput (after TTFT)

Subtracting TTFT to measure pure decode speed:

| Context | macbook2 | gigul2 | Ratio |
|---------|----------|--------|-------|
| 50K | 252 tok / 98.8s = **2.6 tok/s** | 682 tok / 19.4s = **35.1 tok/s** | 13.5x slower |
| 55K | 652 tok / 313.1s = **2.1 tok/s** | 645 tok / 21.1s = **30.6 tok/s** | 14.6x slower |

The actual decode throughput shows a ~14x penalty, which is much larger than the 2.4x memory bandwidth ratio. This suggests the Metal backend or LM Studio configuration is significantly less optimized for this model/context size than the raw llama.cpp with Vulkan on the 7900 XTX.

### Super-Linear Context Degradation (macbook2)

| Metric | 50K Context | 55K Context | Degradation |
|--------|-------------|-------------|-------------|
| **TTFT** | 173.040s | 265.822s | **54% slower** (+5K tokens) |
| **Throughput** | 0.93 tok/s | 1.13 tok/s | Slightly better (more tokens generated) |
| **Decode speed** | 2.6 tok/s | 2.1 tok/s | **19% slower** |

The TTFT degradation pattern (54% for +5K tokens) is similar to gigul2 (59%), confirming O(n^2) attention scaling.

## Hardware Details

### macbook2 (this test)
- **CPU**: Apple M2 Max
- **RAM**: 96GB unified memory
- **Memory Bandwidth**: ~400 GB/s
- **GPU**: Integrated (38-core GPU in M2 Max)
- **OS**: macOS 15.7.3 (arm64)
- **Backend**: LM Studio → llama.cpp (Metal)

### gigul2 (comparison)
- **CPU**: (Linux desktop)
- **GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
- **RAM**: 128GB system
- **Memory Bandwidth**: 960 GB/s (GPU)
- **Backend**: llama.cpp (Vulkan) with flash-attn, q8_0 KV cache, mlock

## Conclusions

1. **For TTFT-dominated tasks**: macbook2 is ~2x slower than gigul2, roughly matching memory bandwidth ratio. Acceptable for batch processing.

2. **For throughput-critical tasks**: macbook2 is 4-14x slower depending on metric. Not suitable for interactive use with large contexts.

3. **Absolute performance**:
   - 50K context TTFT of 173s (nearly 3 minutes) is impractical for interactive use
   - Generation speed of 2-3 tok/s means ~4 minutes for a 512-token response
   - Total round-trip: ~7-12 minutes per query with 50K+ context

4. **Best use case on macbook2**: Small context (<10K tokens) where the M2 Max's unified memory advantage (96GB vs 24GB VRAM) allows loading larger models that wouldn't fit on the 7900 XTX.

5. **The 7900 XTX wins decisively** for large-context LLM inference due to its 2.4x higher memory bandwidth and optimized Vulkan backend in llama.cpp.

## Reproduction

```bash
python3 bench_longcontext_macbook.py \
  --base http://localhost:1234 \
  --model glm-4.7-flash \
  --prefill-tokens 40000 \
  --prompt-tokens 10000,15000 \
  --runs 1

# Results saved to: benchmark_longcontext_macbook2.jsonl
```

## Files

- **benchmark_longcontext_macbook2.jsonl**: Raw JSON results (2 runs)
- **bench_longcontext_macbook.py**: Benchmark script (stdlib, no dependencies)
- **LONG_CONTEXT_RESULTS_MACBOOK2.md**: This document
- **LONG_CONTEXT_RESULTS.md**: gigul2 results for comparison
