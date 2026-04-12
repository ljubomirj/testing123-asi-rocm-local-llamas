# Benchmark Summary: Qwen3.5-27B with Draft Model (0.8B)
## ROCm/AMD 7900 XTX - llama.cpp hip-rocwmma

**Date:** 2026-03-05
**Main Model:** Qwen3.5-27B-UD-Q4_K_XL.gguf
**Draft Model:** Qwen3.5-0.8B-UD-Q4_K_XL.gguf
**Hardware:** AMD 7900 XTX (24GB VRAM)
**Build:** llama.cpp hip-rocwmma build-gigul2-hip-rocwmma

### Configuration
- Flash Attention: ON
- KV Cache Type: q8_0
- Draft KV Cache: q8_0
- Threads: 10 (batch), 10 (standard)
- Context Size: 130K tokens
- GPU Layers: All

### Results Table

| Context        | Prefill | TTFT (s) | Thruput (t/s) |
|----------------|---------|----------|---------------|
| None (50 tok)  | 0       | 0.258    | 27.8          |
| None (100 tok) | 0       | 0.316    | 28.1          |
| Small (15K)    | 5K      | 17.111   | 15.7          |
| Small (20K)    | 5K      | 28.051   | 12.2          |
| Mid (30K)      | 20K     | 27.935   | 13.2          |
| Mid (35K)      | 20K     | 43.969   | 9.5           |
| Long (50K)     | 40K     | 43.087   | 9.7           |
| Long (55K)     | 40K     | 66.416   | 7.2           |
| Longlong (110K)| 100K    | 89.091   | 5.8           |
| Longlong (115K)| 100K    | 133.189  | 4.2           |

### Notes

**IMPORTANT:** Speculative decoding was NOT actually enabled in this run.
The server log showed: "speculative decoding not supported by this context"

This is because the `--kv-unified` flag is incompatible with speculative decoding.
To enable speculative decoding, the server needs to be restarted WITHOUT `--kv-unified`.

The draft model was loaded but not used for speculation in these benchmarks.

### To enable speculative decoding:

Remove `--kv-unified` from the server arguments and restart the server.
The correct speculative decoding arguments are:
- `--model-draft "$MODEL_DRAFT_PATH"`
- `--cache-type-k-draft q8_0`
- `--cache-type-v-draft q8_0`

But WITHOUT `--kv-unified`
