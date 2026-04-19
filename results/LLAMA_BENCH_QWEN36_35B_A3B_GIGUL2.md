# Qwen3.6-35B-A3B Q4_K_S llama-bench Style Results - gigul2

**Date**: 2026-04-17

**Model**: `Qwen3.6-35B-A3B-UD-Q4_K_S.gguf` (20GB)

**Hardware**: `gigul2` (AMD 7900XTX 24GB VRAM, Xeon 10-core, 128GB RAM, HIP ROCm)

**Server**: llama.cpp (build-gigul2-hip-rocwmma)

**Server Parameters**:
- Context: 131072
- Flash attention: ON
- KV cache: q8_0
- GPU layers: all

## Results Summary

### PP/TG Matrix (Streaming)

| PP | TG | TTFT | PP Speed* | TG Speed |
|---:|---:|---:|---:|---:|
| 256 | 512 | 6.78s | 37.8 t/s | 57.8 t/s |
| 512 | 512 | 7.90s | 64.8 t/s | 57.4 t/s |
| 1024 | 512 | 7.37s | 138.9 t/s | 53.2 t/s |
| 1024 | 1024 | 7.39s | 138.6 t/s | 53.2 t/s |
| 2048 | 512 | 8.79s | 233.1 t/s | 57.4 t/s |
| 2048 | 1024 | 8.76s | 233.7 t/s | 55.9 t/s |
| 4096 | 512 | 7.60s | 542.3 t/s | 58.3 t/s |
| 4096 | 1024 | 6.90s | 593.4 t/s | 58.4 t/s |
| 8192 | 512 | 9.89s | 903.8 t/s | 59.9 t/s |
| 8192 | 1024 | 7.03s | 1165.5 t/s | 53.9 t/s |

*PP Speed = PP / TTFT (includes model's thinking time). Actual prompt processing is much faster.

## Key Observations

1. **TG speed is very consistent**: **53-60 t/s** across all PP sizes. Rock solid.

2. **PP speed scales linearly**: From 38 t/s at PP=256 up to 1166 t/s at PP=8192.

3. **TTFT is remarkably low**: 6.8-9.9s even at 8K context. This includes model thinking time.

4. **Small TG (32-256) failed**: The model's thinking phase consumed all tokens before generating visible content. Need TG>=512 for reliable results.

5. **No OOM or errors at 8K context**: 131K context gives plenty of headroom.

## Comparison: gigul2 (7900XTX) vs macbook2 (M2 Max)

Both running Qwen3.6-35B-A3B:

| Metric | gigul2 (7900XTX) | macbook2 (M2 Max) | Ratio |
|--------|------------------|-------------------|--------|
| Quant | Q4_K_S (20GB) | Q6_K_XL (31GB) | - |
| TG speed (typical) | **53-60 t/s** | **28-42 t/s** | **1.4x faster** |
| PP speed (PP=4096) | **542-593 t/s** | **274-302 t/s** | **2.0x faster** |
| TTFT (PP=4096) | **6.9-7.6s** | **13.6-15.2s** | **2.0x faster** |

**The 7900XTX is roughly 1.4-2.0x faster** than the M2 Max for this model, despite the M2 Max using a higher-quality quantization. The GPU's higher memory bandwidth (960 GB/s vs 400 GB/s) is the key advantage.

## Cost-Performance

| Setup | Cost (used) | TG Speed | Speed/$ |
|-------|-------------|----------|---------|
| AMD 7900XTX | ~$620 | 53-60 t/s | **0.09 t/s per $** |
| Apple M2 Max | ~$2000+ | 28-42 t/s | 0.02 t/s per $ |

The 7900XTX offers **~4x better speed-per-dollar** for local LLM inference.
