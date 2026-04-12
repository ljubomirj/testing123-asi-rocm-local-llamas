# Qwen3-Coder-Next Benchmark Results

**Date**: 2026-02-15
**Build**: llama.cpp hip-rocwmma-new (build-gigul2-hip-rocwmma-new)
**Model**: Qwen3-Coder-Next-UD-Q5_K_XL-00001-of-00003.gguf
**GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
**Backend**: HIP with rocWMMA support
**Test Label**: llama.cpp hip-rocwmma-new linux qwen3-coder-next

## Model Specs

- **Parameters**: 80B (79.67B)
- **Architecture**: MoE (512 experts, 10 active per token)
- **Context**: 262K tokens (trained)
- **Vocab**: 151936
- **Embedding**: 2048
- **File Size**: 56.8 GB (3 GGUF parts)

## Benchmark Results Summary

### None-Context (No prefill, 25-100 tokens)
| Context | TTFT | Throughput |
|---------|------|------------|
| 25 | 1.072s | 11.3 tok/s |
| 50 | 1.164s | 11.2 tok/s |
| 100 | 1.355s | 12.5 tok/s |

### Small-Context (2K prefill + 10K/15K = 12K-17K total)
| Context | TTFT | Throughput |
|---------|------|------------|
| 12K | 27.684s | 7.4 tok/s |
| 17K | 40.966s | 6.3 tok/s |

### Mid-Context (10K prefill + 10K/15K = 20K-25K total)
| Context | TTFT | Throughput |
|---------|------|------------|
| 20K | 31.095s | 7.2 tok/s |
| 25K | 45.841s | 5.6 tok/s |

### Long-Context (40K prefill + 10K/15K = 50K-55K total)
| Context | TTFT | Throughput |
|---------|------|------------|
| 50K | 41.999s | 6.0 tok/s |
| 55K | 61.535s | 5.1 tok/s |

### Longlong-Context (100K prefill + 10K/15K = 110K-115K total)
| Context | TTFT | Throughput |
|---------|------|------------|
| 110K | 64.590s | 4.7 tok/s |
| 115K | 94.448s | 4.0 tok/s |

## Key Findings

1. **Baseline decode speed**: ~11-12 tok/s with minimal context (much slower than GLM-4.7-Flash's ~88 tok/s)
2. **Model size impact**: 80B MoE model processes ~10x slower than 30B GLM-4.7-Flash
3. **Cache effectiveness**: Excellent - warm prefill 2-5s vs cold 87-269s
4. **Scaling**: Expected O(n²) degradation with context size
5. **MoE overhead**: 512 experts with 10 active per token adds significant compute

## Comparison: GLM-4.7-Flash Q4 vs Qwen3-Coder-Next Q5

| Context | GLM-4.7 Q4 TTFT | Qwen3 Q5 TTFT | GLM Throughput | Qwen Throughput |
|---------|-------------------|-----------------|----------------|-----------------|
| None (25) | 0.394s | 1.072s | 83.4 tok/s | 11.3 tok/s |
| Small (12K) | - | 27.684s | - | 7.4 tok/s |
| Mid (20K) | 9.126s | 31.095s | 41.5 tok/s | 7.2 tok/s |
| Long (50K) | 20.792s | 41.999s | 21.6 tok/s | 6.0 tok/s |
| Longlong (110K) | 44.235s | 64.590s | 11.5 tok/s | 4.7 tok/s |

**Qwen3-Coder-Next is ~3-6x slower** than GLM-4.7-Flash due to:
- 2.7x larger model (80B vs 30B)
- MoE routing overhead (512 experts, 10 active)

## Result Files

- `none_context_results.jsonl` - Raw none-context benchmark data
- `small_context_results.jsonl` - Raw small-context benchmark data
- `mid_context_results.jsonl` - Raw mid-context benchmark data
- `long_context_results.jsonl` - Raw long-context benchmark data
- `longlong_context_results.jsonl` - Raw longlong-context benchmark data
