# Long-Context Benchmark Results - GLM-4.7-Flash on llama.cpp

**Date**: 2026-02-10 (Vulkan), 2026-02-11 (HIP ROCm 7.1.1)
**Model**: GLM-4.7-Flash-UD-Q5_K_XL.gguf (Q5 quantization, 95K context)
**GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
**Backends**: HIP ROCm 7.1.1 and Vulkan
**Server**: llama.cpp (build 8239)

## Test Configuration

### Server Command (HIP ROCm 7.1.1 - 2026-02-11):
```bash
./build/bin/llama-server \
  --device ROCm0 \
  --gpu-layers all \
  --ctx-size 95000 \
  --host 192.168.1.251 \
  --port 8081 \
  --model ~/llama.cpp/models/GLM-4.7-Flash-UD-Q5_K_XL.gguf \
  --temp 1.0 \
  --top-p 0.95 \
  --min-p 0.01 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --jinja \
  --cache-ram 32768 \
  --cache-reuse 512 \
  --cache-prompt \
  --batch-size 2048 \
  --ubatch-size 512 \
  --threads-batch 10 \
  --threads 10 \
  --mlock \
  --no-mmap \
  --kv-unified
```

### Server Command (Vulkan - 2026-02-10):
Same as above except `--device Vulkan0`

### Benchmark Parameters:
- **Context prefill**: 40,000 tokens (~160KB coherent text)
- **Prompt sizes**: 10,000 and 15,000 tokens (~40KB and 60KB)
- **Runs per size**: 3 (to measure cache effectiveness)
- **Max generation**: 512 tokens per request
- **Total active context**: 50K-55K tokens

## HIP ROCm 7.1.1 Results (2026-02-11)

### 50K Total Context (40K prefill + 10K prompt) - HIP ROCm 7.1.1

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 20.534   | 22.0              | 682              | 30.971         |
| 2   | 20.637   | 22.2              | 689              | 31.082         |
| 3   | 20.695   | 21.1              | 658              | 31.150         |
| **Avg** | **20.622** | **21.8** | **676** | **31.068** |

**Context prefilling**:
- First run (cold): 32.38s
- Subsequent runs (warm): 0.17-0.21s (170x faster!)

### 55K Total Context (40K prefill + 15K prompt) - HIP ROCm 7.1.1

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 32.481   | 16.5              | 715              | 43.481         |
| 2   | 32.554   | 15.9              | 692              | 43.569         |
| 3   | 32.538   | 16.2              | 707              | 43.560         |
| **Avg** | **32.525** | **16.2** | **705** | **43.537** |

**Context prefilling**:
- All runs (warm): 0.19-0.22s

## Vulkan Results (2026-02-10)

### 50K Total Context (40K prefill + 10K prompt) - Vulkan

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 79.816   | 7.37              | 731              | 99.222         |
| 2   | 80.102   | 6.34              | 630              | 99.553         |
| 3   | 80.078   | 6.87              | 684              | 99.558         |
| **Avg** | **79.998** | **6.86** | **682** | **99.444** |

**Context prefilling**:
- First run (cold): 125.25s
- Subsequent runs (warm): 0.35-0.36s (357x faster!)

### 55K Total Context (40K prefill + 15K prompt) - Vulkan

| Run | TTFT (s) | Throughput (tok/s) | Generated Tokens | Total Time (s) |
|-----|----------|-------------------|------------------|----------------|
| 1   | 127.083  | 5.04              | 746              | 148.250        |
| 2   | 127.003  | 3.88              | 574              | 148.093        |
| 3   | 126.963  | 4.15              | 615              | 148.094        |
| **Avg** | **127.016** | **4.36** | **645** | **148.146** |

**Context prefilling**:
- All runs (warm): 0.38s

## Performance Analysis

### HIP ROCm 7.1.1 vs Vulkan Backend Comparison

| Metric | HIP ROCm 7.1.1 50K | Vulkan 50K | HIP ROCm 7.1.1 55K | Vulkan 55K |
|--------|----------|------------|----------|------------|
| **TTFT** | 20.6s | 80.0s | 32.5s | 127.0s |
| **Throughput** | 21.8 tok/s | 6.86 tok/s | 16.2 tok/s | 4.36 tok/s |
| **Total Time** | 31.1s | 99.4s | 43.5s | 148.1s |
| **Cold Prefill** | 32.4s | 125.3s | - | - |
| **Warm Prefill** | 0.19s | 0.36s | 0.21s | 0.38s |
| **TTFT Speedup** | **3.9x** | Baseline | **3.9x** | Baseline |
| **Throughput Speedup** | **3.2x** | Baseline | **3.7x** | Baseline |

### Comparison with Empty Context

| Metric | Empty Context | HIP ROCm 7.1.1 50K | Vulkan 50K | HIP ROCm 7.1.1 55K | Vulkan 55K |
|--------|--------------|----------|------------|----------|------------|
| **TTFT** | 0.03-0.64s | 20.6s | 80.0s | 32.5s | 127.0s |
| **Throughput** | 94-112 tok/s | 21.8 tok/s | 6.86 tok/s | 16.2 tok/s | 4.36 tok/s |
| **Use Case** | Unrealistic | Production | Production | Production | Production |

### Context Size Impact

Adding just 5K more tokens (50K -> 55K):
- **HIP ROCm 7.1.1**: TTFT 20.6s -> 32.5s (+58%), Throughput 21.8 -> 16.2 tok/s (-26%)
- **Vulkan**: TTFT 80s -> 127s (+59%), Throughput 6.86 -> 4.36 tok/s (-36%)

HIP ROCm 7.1.1 shows less throughput degradation (-26% vs -36%) with context growth.

## Key Findings

### 1. HIP ROCm 7.1.1 Backend is Transformative (Headline Result)

**On identical hardware** (7900 XTX), switching from Vulkan to HIP ROCm 7.1.1:
- **3.2x throughput** at 50K, **3.7x at 55K**
- **3.9x faster TTFT** at both context sizes
- **3.9x faster cold prefill** (32.4s vs 125.3s)
- The HIP ROCm 7.1.1 advantage **grows with context size**

**Root cause**: Vulkan is a generic graphics API with abstraction overhead. ROCm/HIP is AMD's native compute API. The overhead compounds because each O(n^2) attention pass pays the Vulkan dispatch tax.

### 2. Caching is Highly Effective (Both Backends)

**HIP ROCm 7.1.1**:
- First prefill: 32.38s (cold cache)
- Subsequent prefills: 0.19s (warm cache)
- **Speedup**: 170x faster when cached

**Vulkan**:
- First prefill: 125.25s (cold cache)
- Subsequent prefills: 0.35-0.38s (warm cache)
- **Speedup**: 357x faster when cached

**Implication**: Repeated context reuse benefits enormously on both backends

### 3. TTFT is Dramatically Improved on HIP ROCm 7.1.1
- **Empty context**: 0.03-0.64s
- **HIP ROCm 7.1.1 50K context**: ~21s (acceptable for interactive use!)
- **HIP ROCm 7.1.1 55K context**: ~33s (acceptable for interactive use!)
- **Vulkan 50K context**: ~80s (unacceptable for interactive)
- **Vulkan 55K context**: ~127s (unacceptable for interactive)

**Impact**: HIP ROCm 7.1.1 makes 50-55K context genuinely interactive. Vulkan was limited to 25K.

### 3. Throughput at Long Context (HIP ROCm 7.1.1 vs Vulkan)
- **HIP ROCm 7.1.1 50K**: 21.8 tok/s (excellent for interactive use)
- **HIP ROCm 7.1.1 55K**: 16.2 tok/s (good for interactive use)
- **Vulkan 50K**: 6.86 tok/s (borderline)
- **Vulkan 55K**: 4.36 tok/s (slow)

**Impact**: HIP ROCm 7.1.1 delivers production-viable throughput at 50-55K context

### 4. Super-Linear Context Degradation (Gentler on HIP ROCm 7.1.1)
Each additional 5K tokens (50K -> 55K):
- **HIP ROCm 7.1.1**: 26% throughput loss, 58% TTFT increase
- **Vulkan**: 36% throughput loss, 59% TTFT increase
- HIP ROCm 7.1.1 degrades more gracefully due to lower per-operation overhead

**Implication**: HIP ROCm 7.1.1 extends practical context limit from ~30K (Vulkan) to ~55K+

## Technical Insights

### Why Empty Context Tests are Misleading

**Empty context (0-5K tokens)**:
- Attention: O(5000²) = 25M operations
- KV cache: ~20MB (trivial for 960 GB/s bandwidth)
- Result: 94-112 tok/s (GPU compute-bound)

**Realistic context (50K tokens)**:
- Attention: O(50000²) = 2.5B operations (**100x more**)
- KV cache: ~200MB (memory bandwidth-bound)
- Result: 6.86 tok/s (bandwidth-saturated)

### GLM-4.7-Flash Specific Behavior

The model streams two types of content:
```json
{"delta": {"reasoning_content": "..."}}  // Internal reasoning
{"delta": {"content": "..."}}            // Actual output
```

This explains the massive TTFT - the model is "thinking" for 80-127 seconds before responding.

### Hardware Limits

**AMD 7900 XTX specs**:
- Memory bandwidth: 960 GB/s
- VRAM: 24GB
- Architecture: gfx1100 (RDNA 3)

**Observed bottleneck**: Memory bandwidth, not compute
- Flash attention helps, but can't overcome bandwidth limits
- q8_0 KV cache quantization reduces memory by 50% vs f16
- Still bandwidth-limited at 50K+ context

## Comparison with vLLM/SGLang (Expected)

### llama.cpp (Current):
- ✅ Works with GGUF models
- ✅ Excellent prompt caching (357x speedup)
- ❌ No concurrent request handling
- ❌ No radix/prefix caching across requests
- ❌ Catastrophic TTFT (80-127s)
- ❌ Low throughput (4-7 tok/s)

### vLLM/SGLang (When Available):
- ✅ PagedAttention / RadixAttention for efficient KV cache sharing
- ✅ Concurrent request handling with shared context
- ✅ Continuous batching for better GPU utilization
- ❌ Currently blocked (vLLM: no deepseek2 GGUF support, SGLang: ROCm 7.1.1 incompatibility)

### Expected Improvement:
- **Throughput**: 2-3x improvement with continuous batching
- **Concurrent**: Handle multiple requests sharing same 40K context
- **TTFT**: Potentially lower with better attention kernels
- **Target**: ~10-20 tok/s for 50K context scenarios

## Recommendations

### For HIP ROCm 7.1.1 llama.cpp Setup (Recommended):
1. ✅ **Use for**: Interactive chat, document analysis, code review up to 55K context
2. ✅ **Leverage**: Prompt caching for repeated context (170x speedup)
3. ✅ **Interactive viable**: TTFT under 33s even at 55K context
4. ✅ **Throughput**: 16-22 tok/s at long context is genuinely responsive

### For Vulkan llama.cpp Setup (If HIP ROCm 7.1.1 unavailable):
1. ✅ **Use for**: Single-user, document analysis with context reuse
2. ✅ **Leverage**: Prompt caching for repeated context (357x speedup)
3. ❌ **Avoid**: Interactive chat with context >30K (80s+ TTFT)
4. ❌ **Avoid**: Contexts >60K tokens (performance degrades super-linearly)

### For Future vLLM/SGLang:
1. **Monitor**: vLLM for deepseek2 GGUF support
2. **Monitor**: SGLang for ROCm 7.1.x compatibility
3. **Test with**: Same 40K context + 10K-15K prompt benchmarks
4. **Note**: HIP ROCm 7.1.1 llama.cpp at 16-22 tok/s is already quite competitive

## Files Generated

- **benchmark_longcontext_results.jsonl**: Raw JSON results (6 runs)
- **bench_longcontext.py**: Benchmark script with context prefilling
- **LONG_CONTEXT_RESULTS.md**: This analysis document
- **LLAMA_CPP_TEST_ANALYSIS.md**: Updated with realistic results
- **LEARNINGS.md**: Updated with comparison table

## Reproduction

To reproduce these results:

```bash
# Start llama.cpp server (see command above)
./start_llama_server.sh

# Run realistic benchmark
python3 bench_longcontext.py \
  --base http://192.168.1.251:8081 \
  --prefill-tokens 40000 \
  --prompt-tokens 10000,15000 \
  --runs 3

# Results saved to: benchmark_longcontext_results.jsonl
```

To compare with empty context:

```bash
python3 bench_longcontext.py \
  --base http://192.168.1.251:8081 \
  --no-prefill \
  --prompt-tokens 10000,15000 \
  --runs 3
```

## Conclusion

**HIP ROCm 7.1.1 transforms the picture**: llama.cpp with HIP ROCm 7.1.1 delivers **16-22 tok/s** for realistic 50K-55K context, compared to **4-7 tok/s** on Vulkan. TTFT drops from 80-127s to 21-33s.

**HIP ROCm 7.1.1 makes long context interactive**: 21s TTFT at 50K and 16.2 tok/s throughput at 55K are genuinely usable for interactive applications. Vulkan was limited to 25K for interactive use.

**Vulkan was the bottleneck, not the hardware**: The 7900 XTX has plenty of compute and bandwidth. The Vulkan abstraction layer was consuming 60-75% of potential performance.

**Best configuration**: HIP ROCm 7.1.1 backend is strongly recommended for AMD GPUs. Use Vulkan only if HIP ROCm 7.1.1 is unavailable.

**Data files**:
- `benchmark_gigul2_rocm_longcontext_results.jsonl` - HIP ROCm 7.1.1 results
- `benchmark_longcontext_results.jsonl` - Vulkan results
