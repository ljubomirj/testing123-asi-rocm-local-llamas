# Carnice-Qwen3.6-MoE-35B-A3B Q4_K_S llama-bench Style Results - gigul2

**Date**: 2026-04-20

**Model**: `Carnice-Qwen3.6-MoE-35B-A3B-Q4_K_S.gguf` (~19.9GB)

**Hardware**: `gigul2` (AMD 7900XTX 24GB VRAM, Xeon 10-core, 128GB RAM, HIP ROCm)

**Server**: llama.cpp (build-gigul2-hip-rocwmma)

**Server Parameters**:
- Context: 130000
- Flash attention: ON
- KV cache: q8_0
- GPU layers: all
- Reasoning: ON with budget 5000

## Results Summary

### PP/TG Matrix (Streaming)

| PP | TG | TTFT | PP Speed* | TG Speed |
|---:|---:|---:|---:|---:|
| 128 | 512 | 9.24s | 13.9 t/s | 67.3 t/s |
| 256 | 512 | 8.65s | 29.6 t/s | 58.4 t/s |
| 256 | 1024 | 8.67s | 29.5 t/s | 58.7 t/s |
| 512 | 2048 | 22.73s | 22.5 t/s | 62.5 t/s |
| 4096 | 2048 | 36.48s | 112.3 t/s | 68.5 t/s |

*PP Speed = PP / TTFT (includes model's thinking time). Actual prompt processing is much faster.

## Key Observations

1. **TG speed is very consistent**: **58-68 t/s** across all PP sizes. Rock solid.

2. **PP speed scales linearly**: From 14 t/s at PP=128 up to 112 t/s at PP=4096.

3. **TTFT increases with PP**: From 8.65s at PP=256 to 36.48s at PP=4096.

4. **Small TG (32-256) failed**: The model's thinking phase consumed all tokens before generating visible content. Need TG>=512 for reliable results.

5. **No OOM or errors at 4K context**: 130K context gives plenty of headroom.

## Comparison: Carnice Q4_K_S vs UD-IQ4_XS (Same 7900 XTX)

Both running Qwen3.6-35B-A3B variants:

| Metric | Carnice Q4_K_S | UD-IQ4_XS | Ratio |
|--------|----------------|-----------|-------|
| Quant | Q4_K_S (~19.9GB) | IQ4_XS (~19GB) | - |
| TG speed (typical) | **58-68 t/s** | **53-60 t/s** | Similar |
| PP speed (PP=4096) | **112 t/s** | **542-593 t/s** | 0.2x |
| TTFT (PP=4096) | **36.5s** | **6.9-7.6s** | 4.8x slower |

**Note**: The Carnice variant was tested with reasoning ON (5000 token budget), which significantly increases TTFT and reduces effective PP speed. The UD-IQ4_XS variant was tested with reasoning OFF, explaining the large difference in PP speed.

## Cost-Performance

| Setup | Cost (used) | TG Speed | Speed/$ |
|-------|-------------|----------|---------|
| AMD 7900XTX | ~$620 | 58-68 t/s | **0.11 t/s per $** |

The 7900XTX offers excellent throughput for local LLM inference.

---
