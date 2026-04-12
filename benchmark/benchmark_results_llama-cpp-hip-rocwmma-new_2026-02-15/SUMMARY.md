# llama.cpp hip-rocwmma-new Benchmark Results

**Date**: 2026-02-15
**Build**: llama.cpp hip-rocwmma-new (build-gigul2-hip-rocwmma-new)
**Model**: GLM-4.7-Flash-UD-Q4_K_XL.gguf
**GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
**Backend**: HIP with rocWMMA support
**Test Label**: llama.cpp hip-rocwmma-new linux glm-4.7-flash

## Server Command

```bash
build-gigul2-hip-rocwmma-new/bin/llama-server \
  --device ROCm0 \
  --gpu-layers all \
  --ctx-size 190000 \
  --host 192.168.1.251 \
  --port 8081 \
  --model /home/ljubomir/llama.cpp/models/GLM-4.7-Flash-UD-Q4_K_XL.gguf \
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

## Benchmark Results Summary

### None-Context (No prefill, 25-100 tokens)
| Context | TTFT | Throughput |
|---------|------|------------|
| 25 | 0.394s | 83.4 tok/s |
| 50 | 0.069s | 88.1 tok/s |
| 100 | 0.095s | 91.1 tok/s |

### Small-Context (10K prefill + 10K/15K = 20K-25K total)
| Context | TTFT | Throughput |
|---------|------|------------|
| 20K | 8.920s | 38.3 tok/s |
| 25K | 15.230s | 29.5 tok/s |

### Mid-Context (10K prefill + 10K/15K = 20K-25K total)
| Context | TTFT | Throughput |
|---------|------|------------|
| 20K | 9.126s | 41.5 tok/s |
| 25K | 15.230s | 31.1 tok/s |

### Long-Context (40K prefill + 10K/15K = 50K-55K total)
| Context | TTFT | Throughput |
|---------|------|------------|
| 50K | 20.792s | 21.6 tok/s |
| 55K | 32.690s | 15.0 tok/s |

### Longlong-Context (100K prefill + 10K/15K = 110K-115K total)
| Context | TTFT | Throughput |
|---------|------|------------|
| 110K | 44.235s | 11.5 tok/s |
| 115K | 67.687s | 8.1 tok/s |

## Key Findings

1. **Baseline decode speed**: ~88-91 tok/s with minimal context
2. **Cache effectiveness**: Excellent - warm prefill 0.17-0.45s vs cold 155s for 100K
3. **Scaling**: Expected degradation with context size (O(n²) attention pattern)
4. **rocWMMA impact**: Similar to previous hip-rocwmma build - no significant change expected

## Result Files

- `none_context_results.jsonl` - Raw none-context benchmark data
- `small_context_results.jsonl` - Raw small-context benchmark data
- `mid_context_results.jsonl` - Raw mid-context benchmark data
- `long_context_results.jsonl` - Raw long-context benchmark data
- `longlong_context_results.jsonl` - Raw longlong-context benchmark data
