# Qwen3-Coder-Next-UD-Q5_K_XL Benchmark Results
## AMD 7900 XTX (24GB VRAM) + 128GB RAM
## Date: 2026-02-15

### Model Details
- **Name**: Qwen3-Coder-Next-UD-Q5_K_XL (Unsloth)
- **Architecture**: qwen3next (MoE - Mixture of Experts)
- **Parameters**: 80B (512 total experts, 10 active per token)
- **Layers**: 48 blocks
- **Quantization**: Q5_K_XL
- **File Size**: ~53GB total (3 GGUF parts)
- **Context Length**: 262,144 tokens

### Hardware
- **GPU**: AMD Radeon RX 7900 XTX (gfx1100)
- **VRAM**: 25.75 GB
- **RAM**: 128 GB
- **Build**: llama.cpp commit 83061e096 with ROCm 7.1.1 + rocWMMA
- **Flash Attention**: Enabled (-fa 1)

### Key Finding: Optimal Configuration

```
--n-cpu-moe 29 --threads 20 --flash-attn on
```

This configuration:
- Keeps experts from layers 0-28 on CPU (29 layers)
- Keeps experts from layers 29-47 on GPU (19 layers)
- Achieves **13.58 tokens/sec** generation speed
- Achieves **114.57 tokens/sec** prompt processing
- Fits within 24GB VRAM

### Benchmark Results Comparison

| n-cpu-moe | Threads | Prompt (128 tok) | Generation (64 tok) | Status |
|-----------|----------|-------------------|----------------------|--------|
| 28 | 10 | OOM | OOM | ❌ Out of memory |
| **29** | **10** | **112.55 t/s** | **9.44 t/s** | ✅ **Optimal** |
| **29** | **20** | **114.57 t/s** | **13.58 t/s** | ✅ **Best** |
| 30 | 10 | 110.46 t/s | 9.58 t/s | ✅ |
| 30 | 20 | 106.51 t/s | 13.15 t/s | ✅ |
| 31 | 20 | 105.75 t/s | 12.89 t/s | ✅ |
| 32 | 20 | 104.25 t/s | 12.94 t/s | ✅ |
| 35 | 10 | 100.37 t/s | 7.75 t/s | ✅ |
| 40 | 10 | 89.21 t/s | 7.01 t/s | ✅ |
| 48 | 10 | ~75 t/s | 5.90 t/s | ✅ All CPU |

### Performance at Longer Context (2048 prompt + 128 gen)

| n-cpu-moe | Threads | Prompt (2048 tok) | Generation (128 tok) |
|-----------|----------|-------------------|----------------------|
| 29 | 20 | 271.18 t/s | 13.77 t/s |

### Key Insights

1. **--n-cpu-moe 29 is the sweet spot** - minimum CPU offload that fits in 24GB VRAM
2. **More threads help** - 20 threads improves generation speed by ~40% over 10 threads
3. **Less CPU offload = faster** - Each layer moved from CPU to GPU adds ~0.3-0.5 t/s
4. **Prompt processing is fast** - 114+ t/s even with MoE offloading
5. **The Reddit recommendation (n-cpu-moe 27)** is for RTX 5090 with 32GB VRAM, not 24GB

### Server Startup Command

```bash
/data1/data/llama.cpp/build-gigul2-hip-rocwmma-new/bin/llama-server \
  --device ROCm0 \
  --gpu-layers all \
  --ctx-size 262144 \
  --host 192.168.1.251 \
  --port 8082 \
  --model ~/llama.cpp/models/UD-Q5_K_XL/Qwen3-Coder-Next-UD-Q5_K_XL-00001-of-00003.gguf \
  --threads 20 \
  --threads-batch 10 \
  --flash-attn on \
  --n-cpu-moe 29 \
  --temp 1.0 \
  --top-p 0.95 \
  --min-p 0.01 \
  --batch-size 2048 \
  --ubatch-size 512 \
  > server_qwen3.log 2>&1
```

Note: Add your preferred cache parameters if needed:
```
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --cache-ram 32768 \
  --cache-reuse 512 \
  --cache-prompt
```

### Comparison with Reddit Results (RTX 5090 + Ryzen 7600X)

| Metric | RTX 5090 (32GB) | AMD 7900 XTX (24GB) |
|--------|-------------------|----------------------|
| n-cpu-moe | 27 | 29 |
| VRAM used | ~32GB | ~24GB |
| Threads | 6 | 20 (dual Xeon) |
| Generation speed | Not reported | 13.58 t/s |

### Notes

- The model is an **80B parameter MoE model** with 512 experts (10 active per token)
- Even with CPU offloading, this is significantly faster than smaller models
- Qwen3-Coder-Next has optimized graph operations (commit 1725e316c)
- The --n-cpu-moe parameter controls which LAYERS have experts on CPU, not which experts
- Layer 47 (last layer) has different structure and is always fully loaded to GPU
