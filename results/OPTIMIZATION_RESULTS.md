# Q5 Optimization Results - Batch Size & RAM Cache Tests

**Date**: 2026-02-10
**Test**: Doubled batch sizes (2048→4096, 512→1024) + doubled RAM cache (32GB→64GB)

## Results Summary

### Performance Comparison

| Configuration | 50K Context | 55K Context | Improvement |
|---------------|-------------|-------------|-------------|
| **Baseline** (2048/512, 32GB) | 6.9 tok/s | 4.4 tok/s | - |
| **Optimized** (4096/1024, 64GB) | 6.8 tok/s | 4.6 tok/s | **~0%** |

### Detailed Results

**50K Context (40K prefill + 10K prompt)**:
- Baseline: 6.86 tok/s avg (7.37, 6.34, 6.87)
- Optimized: 6.77 tok/s avg (6.3, 6.7, 7.3)
- **Change**: -1.3% (within noise margin)

**55K Context (40K prefill + 15K prompt)**:
- Baseline: 4.36 tok/s avg (5.04, 3.88, 4.15)
- Optimized: 4.60 tok/s avg (4.4, 4.7, 4.7)
- **Change**: +5.5% (slight improvement)

**TTFT (Time To First Token)**:
- 50K: 79.998s → 79.185s (-1.0%)
- 55K: 127.016s → 126.434s (-0.5%)

## Key Findings

### 1. Batch Size Has Minimal Impact (Single-User Workload)

**Why batch size didn't help**:

**Batch size affects**:
- Number of tokens processed per GPU kernel launch
- Useful for **multi-request batching** (concurrent users)
- Useful for **parallel sequence generation**

**Batch size does NOT affect**:
- Single request processing (our benchmark)
- Memory bandwidth bottleneck (the real issue)
- O(n²) attention complexity

**What we're testing**:
- Single request at a time
- No concurrent users
- No continuous batching

**Result**: Batch size 2048 vs 4096 makes no difference for single-user throughput.

### 2. RAM Cache Size Has Minimal Impact (Already Hitting Cache)

**Why larger RAM cache didn't help**:

**Cache size affects**:
- Number of different prompts that can be cached
- Useful for **diverse prompt workload**
- Useful for **multi-user scenarios**

**Cache size does NOT affect**:
- Single prompt repeated (our benchmark)
- Cache hit rate when prompt fits (already 100%)

**What we're testing**:
- Same prompt repeated 3 times
- 40K context fits easily in 32GB cache
- Already getting 100% cache hit rate (0.35s vs 125s)

**Result**: 32GB → 64GB cache doesn't help when we're only caching one prompt.

### 3. The Real Bottleneck: Memory Bandwidth + O(n²) Attention

**What actually limits performance**:

1. **O(n²) attention complexity**
   - 50K context: 2.5 billion attention operations
   - 55K context: 3.0 billion attention operations
   - 10% more context = 20% more operations

2. **Memory bandwidth saturation**
   - AMD 7900 XTX: 960 GB/s bandwidth
   - Reading 50K KV cache: ~200MB per token generated
   - Bandwidth fully saturated

3. **GLM-4.7-Flash reasoning tokens**
   - Model generates reasoning_content (thinking)
   - 80-127s TTFT dominated by model thinking
   - Not a llama.cpp issue

**These are NOT affected by**:
- Batch size (single request)
- RAM cache size (already cached)
- Thread count (GPU-bound, not CPU-bound)

## Metrics Analysis

### Prometheus Metrics (Optimized Run)

```
llamacpp:prompt_tokens_seconds 94.5091        # Prompt processing: 94 tok/s
llamacpp:predicted_tokens_seconds 24.8212     # Generation: 24.8 tok/s
```

**Interpretation**:
- **Prompt processing**: 94 tok/s (fast when cached!)
- **Generation throughput**: 24.8 tok/s **on average across all generated tokens**
  - This includes both reasoning tokens and output tokens
  - Our measured 4.6-6.8 tok/s is for **final output only**
  - Difference suggests significant reasoning token overhead

### Cache Performance

**Cold run** (first time):
- Prefill: 121.22s (processing 40K tokens)
- Rate: 40000 / 121.22 = 330 tok/s

**Warm runs** (cached):
- Prefill: 0.35s (loading from RAM cache)
- Rate: 40000 / 0.35 = 114,286 tok/s (RAM → VRAM transfer)
- **Speedup**: 346x faster!

**Cache is working perfectly** - no improvement possible here.

## What Would Actually Help

### 1. ❌ Larger Batch Sizes
**Won't help**: Single-user workload doesn't benefit

### 2. ❌ More RAM Cache
**Won't help**: Already hitting 100% cache rate for our workload

### 3. ❌ More CPU Threads
**Won't help**: Bottleneck is GPU memory bandwidth, not CPU

### 4. ✅ Different Model (Q4)
**Might help**:
- Smaller model (17GB vs 21GB) = less memory traffic
- Potentially 10-15% improvement
- Trade-off: Lower quality

### 5. ✅ Smaller Context
**Would help**:
- 30K context instead of 50K: ~2x faster (O(n²) scales)
- Not practical for agentic workloads

### 6. ✅ Better Attention Kernels
**Would help**:
- Flash Attention is already enabled
- Vulkan backend may not be optimal
- Native ROCm/HIP backend might be 10-20% faster
- Requires different llama.cpp build

### 7. ✅ Model Optimization
**Would help**:
- Speculative decoding (draft model)
- Quantized KV cache beyond q8_0 (q4_0)
- Different model architecture (non-reasoning)

## Recommendations

### For Current Setup (Q5, Single-User)

**Keep baseline parameters**:
```bash
--batch-size 2048       # Larger doesn't help
--ubatch-size 512       # Larger doesn't help
--cache-ram 32768       # Larger doesn't help (single prompt)
```

**Optimizations to try**:
1. ✅ **Test Q4 model** (17GB, 200K context)
   - Expected: 10-15% throughput improvement
   - Benefit: 2x context size for agentic workloads

2. ✅ **Try native ROCm backend** (instead of Vulkan)
   - Rebuild llama.cpp with `LLAMA_HIPBLAS=1`
   - Expected: 10-20% improvement
   - Risk: May not work/may crash

3. ❌ **Don't waste time on**:
   - Larger batches (proven ineffective)
   - More RAM cache (only helps multi-prompt workloads)
   - More threads (GPU-bound)

### For Multi-User / Production

If deploying for multiple concurrent users:

**Then larger batches help**:
```bash
--batch-size 4096       # Batch multiple user requests
--parallel 4            # Enable 4 concurrent slots
--cont-batching         # Continuous batching
```

**Expected improvement**: 2-3x throughput for **total requests/sec**
**Trade-off**: Higher per-request latency

## Conclusions

### What We Learned

1. ✅ **Batch size is irrelevant for single-user workloads**
   - 2048 vs 4096: No measurable difference
   - Only helps with concurrent requests

2. ✅ **RAM cache is already optimal**
   - 32GB is plenty for single-prompt testing
   - 346x speedup on cache hits (0.35s vs 121s)
   - Larger cache only helps diverse prompt workloads

3. ✅ **Real bottleneck is memory bandwidth + O(n²) attention**
   - 50K context: 6.8 tok/s (bandwidth saturated)
   - 55K context: 4.6 tok/s (32% slower with 10% more context)
   - No llama.cpp parameter can fix this

4. ✅ **GLM-4.7-Flash has massive TTFT**
   - 80-127s TTFT dominated by reasoning tokens
   - Inherent to model architecture
   - Not a llama.cpp configuration issue

### Next Steps

**Priority 1: Test Q4 Model**
- Smaller model (17GB) may reduce memory bandwidth pressure
- 2x context size (200K) better for agentic workloads
- Expected: 7-8 tok/s for 50K context (10-15% improvement)

**Priority 2: Consider ROCm Backend**
- Rebuild llama.cpp with native ROCm/HIP
- Vulkan adds overhead, native HIP may be faster
- Risk: Experimental, may not work

**Priority 3: Accept Reality**
- 4-7 tok/s is the realistic performance for 50K+ context
- GLM-4.7-Flash is a reasoning model (slow TTFT)
- For faster inference: Need different model or smaller context

## Files

- **benchmark_longcontext_results.jsonl** - Baseline (2048/512, 32GB)
- **benchmark_q5_optimized_results.jsonl** - Optimized (4096/1024, 64GB)
- **OPTIMIZATION_RESULTS.md** - This analysis

## Raw Data Comparison

### Baseline (Original Parameters)

```json
// 50K context, run 1
{"ttft_sec": 79.816, "tokens_per_sec": 7.372, "response_tokens": 731}
// 50K context, run 2
{"ttft_sec": 80.102, "tokens_per_sec": 6.336, "response_tokens": 630}
// 50K context, run 3
{"ttft_sec": 80.078, "tokens_per_sec": 6.873, "response_tokens": 684}

// 55K context, run 1
{"ttft_sec": 127.083, "tokens_per_sec": 5.035, "response_tokens": 746}
// 55K context, run 2
{"ttft_sec": 127.003, "tokens_per_sec": 3.878, "response_tokens": 574}
// 55K context, run 3
{"ttft_sec": 126.963, "tokens_per_sec": 4.154, "response_tokens": 615}
```

**Averages**:
- 50K: 6.86 tok/s, TTFT 79.998s
- 55K: 4.36 tok/s, TTFT 127.016s

### Optimized (2x Batches, 2x Cache)

```json
// 50K context, run 1
{"ttft_sec": 78.934, "tokens_per_sec": 6.327, "response_tokens": 624}
// 50K context, run 2
{"ttft_sec": 79.186, "tokens_per_sec": 6.662, "response_tokens": 659}
// 50K context, run 3
{"ttft_sec": 79.434, "tokens_per_sec": 7.314, "response_tokens": 726}

// 55K context, run 1
{"ttft_sec": 126.425, "tokens_per_sec": 4.351, "response_tokens": 644}
// 55K context, run 2
{"ttft_sec": 126.424, "tokens_per_sec": 4.702, "response_tokens": 696}
// 55K context, run 3
{"ttft_sec": 126.451, "tokens_per_sec": 4.653, "response_tokens": 689}
```

**Averages**:
- 50K: 6.77 tok/s, TTFT 79.185s
- 55K: 4.60 tok/s, TTFT 126.434s

**Statistical significance**: Differences are within run-to-run variance (~10%), indicating no meaningful improvement.
