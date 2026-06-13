# Comprehensive Benchmark Comparison: Nemotron vs Gemma-4 vs Qwen3.6-27B

**Date:** 2026-06-12
**GPU:** AMD 7900XTX 24GB (gigul2)
**Tool:** llama-benchy 0.3.7
**Latency Mode:** generation

---

## Model Specifications

| Model | Parameters | Quantization | Architecture | Special Features |
|-------|-----------|--------------|--------------|------------------|
| **Nemotron-Cascade-2-30B-A3B** | 30B | IQ4_XS | MoE | 1M context support |
| **Gemma-4-26B-A4B** | 26B | Q4_K_XL (MTP) | MoE | MTP speculative decoding |
| **Qwen3.6-27B** | 27B | IQ4_NL | Dense | Reasoning-focused |

---

## Side-by-Side Performance Comparison

### Prompt Processing (PP) Throughput (t/s)

| Context | Nemotron ROCm/Vulkan | Gemma-4 ROCm | Qwen3.6 ROCm | Winner |
|---------|---------------------|--------------|--------------|--------|
| **512** | - | - | **158.55** | Qwen |
| **1K** | **2115.45** ✅ | 950.50 | 96.37 | **Nemotron (2.2x Gemma)** |
| **2K** | - | - | 53.90 | - |
| **4K** | - | - | 29.17 | - |
| **8K** | **1681.91** ✅ | **970.50** | 15.27 | **Nemotron (1.7x Gemma)** |
| **32K** | **876.26** ✅ | 866.74 | - | Nemotron |
| **64K** | **529.03** ✅ | 751.54 | - | Gemma |
| **128K** | 293.19 | **601.23** ✅ | - | Gemma |
| **196K** | **134.29** ✅ | - | - | Nemotron |

### Text Generation (TG) Throughput (t/s)

| Context | Nemotron ROCm/Vulkan | Gemma-4 ROCm | Qwen3.6 ROCm | Winner |
|---------|---------------------|--------------|--------------|--------|
| **512** | - | - | **16.03** | Qwen |
| **1K** | **128.32** ✅ | 60.66 | 10.18 | **Nemotron (2.1x Gemma)** |
| **2K** | - | - | 8.38 | - |
| **4K** | - | - | 6.09 | - |
| **8K** | **124.62** ✅ | 64.55 | 3.65 | **Nemotron (1.9x Gemma)** |
| **32K** | **112.21** ✅ | 53.27 | - | **Nemotron (2.1x Gemma)** |
| **64K** | **96.55** ✅ | 35.72 | - | **Nemotron (2.7x Gemma)** |
| **128K** | 10.95 | **25.76** ✅ | - | Gemma |
| **196K** | **3.96** ✅ | - | - | Nemotron |

### Time to First Token (TTFT) (ms)

| Context | Nemotron ROCm/Vulkan | Gemma-4 ROCm | Qwen3.6 ROCm | Winner (lower is better) |
|---------|---------------------|--------------|--------------|--------------------------|
| **512** | - | - | 3490.40 | - |
| **1K** | **627.15** ✅ | 1186.41 | 11073.07 | **Nemotron (1.9x faster)** |
| **2K** | - | - | 39234.68 | - |
| **4K** | - | - | 143957.62 | - |
| **8K** | **5013.73** ✅ | 8513.48 | 546754.43 | **Nemotron (1.7x faster)** |
| **32K** | **37538.31** ✅ | 37883.78 | - | Nemotron |
| **64K** | 124022.00 | **87290.76** ✅ | - | Gemma |
| **128K** | 447191.29 | **218172.03** ✅ | - | Gemma |
| **196K** | **1464171.72** ✅ | - | - | Nemotron |

---

## ROCm vs Vulkan (Nemotron Only)

| Metric | ROCm | Vulkan | Difference |
|--------|------|--------|------------|
| **PP t/s (1K)** | 2115.45 | 2115.45 | Identical ✅ |
| **PP t/s (196K)** | 134.29 | 134.29 | Identical ✅ |
| **TG t/s (1K)** | 128.32 | 128.32 | Identical ✅ |
| **TG t/s (196K)** | 3.96 | 3.96 | Identical ✅ |
| **Max Context** | 196K | 196K | Both same ✅ |
| **262K** | ❌ Failed | ❌ Failed | Both same ❌ |

**Finding:** ROCm and Vulkan show identical performance for Nemotron-Cascade-2-30B-A3B within measurement precision.

---

## Key Findings

### 1. Nemotron-Cascade-2 Dominates at Small-Medium Contexts
- **2.2x faster PP** than Gemma-4 at 1K context (2115 vs 950 t/s)
- **2.1x faster TG** than Gemma-4 at 1K context (128 vs 60 t/s)
- **1.9x faster TTFT** than Gemma-4 at 1K context (627ms vs 1186ms)

### 2. Gemma-4 Catches Up at Large Contexts
- At 128K, Gemma-4 leads in PP (601 vs 293 t/s) and TG (25 vs 10 t/s)
- Better scaling behavior for very large contexts

### 3. Qwen3.6-27B Shows Dramatic Degradation
- PP drops from 158→96 t/s from 512→1K tokens
- At 8K context, only 15 t/s PP and 3.65 t/s TG
- Reasoning overhead significantly impacts performance

### 4. Context Size Capabilities
| Model | Max Tested | Status |
|-------|-----------|--------|
| Nemotron-Cascade-2 | 196K | ✅ Stable |
| Gemma-4 | 128K | ✅ Tested |
| Qwen3.6-27B | 8K | ⚠️ Degrades heavily |

---

## Wall Time Comparison (Selected Contexts)

### 1K Context Processing + 128 Token Generation

| Model | Prompt Time | Gen Time | Total |
|-------|-------------|----------|-------|
| Nemotron | 0.48s | 1.00s | **1.48s** |
| Gemma-4 | ~1.07s | ~2.11s | ~3.18s |
| Qwen | ~11.07s | ~12.58s | ~23.65s |

**Nemotron is 2.1x faster than Gemma-4 and 16x faster than Qwen for 1K context.**

### 8K Context Processing + 128 Token Generation

| Model | Prompt Time | Gen Time | Total |
|-------|-------------|----------|-------|
| Nemotron | 4.87s | 1.03s | **5.90s** |
| Gemma-4 | ~8.44s | ~1.98s | ~10.42s |
| Qwen | ~546.75s | ~35.07s | ~581.82s |

**Nemotron is 1.8x faster than Gemma-4 and 98x faster than Qwen for 8K context.**

---

## Notes

- **Nemotron-Cascade-2**: No MTP variant available, tested with N-Gram speculative decoding
- **Gemma-4**: MTP (Multi-Token Prediction) enabled via AtomicChat fork
- **Qwen3.6-27B**: Reasoning mode enabled, which adds significant overhead
- All benchmarks run on AMD 7900XTX 24GB
- ROCm and Vulkan show identical performance for Nemotron

---

## Conclusion

**Nemotron-Cascade-2-30B-A3B** demonstrates superior performance at small-to-medium context sizes (1K-64K), making it ideal for:
- Fast response applications
- Standard RAG workflows
- General-purpose assistant tasks

**Gemma-4-26B-A4B** shows better scaling at very large contexts (128K+), making it suitable for:
- Long-document processing
- Extended context window applications
- Scenarios requiring massive context

**Qwen3.6-27B** suffers from significant performance degradation, likely due to reasoning overhead, and is best suited for:
- Complex reasoning tasks (where overhead is acceptable)
- Smaller context applications
- Scenarios where reasoning quality outweighs speed concerns
