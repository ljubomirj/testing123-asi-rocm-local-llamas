# MiniMax-M2.5-UD-IQ2_XXS Benchmark Results
## AMD 7900 XTX (24GB VRAM) + 128GB RAM
## Date: 2026-02-15

### Model Details
- **Name**: MiniMax-M2.5-UD-IQ2_XXS
- **Architecture**: minimax-m2 (MoE - Mixture of Experts)
- **Parameters**: **230B** (much larger than Qwen3's 80B)
- **Quantization**: IQ2_XXS (2.0625 bpw - extremely compressed)
- **File Size**: ~69GB total (3 GGUF parts)

### Benchmark Results (128 prompt, 64 generation)

| n-cpu-moe | Status | Prompt (pp128) | Generation (tg64) |
|-----------|--------|----------------|-------------------|
| 33 | OOM | - | - |
| 40 | OOM | - | - |
| 42 | OOM | - | - |
| **43** | ✅ | 40.00 t/s | **4.30 t/s** |
| **44** | ✅ | 39.53 t/s | **4.34 t/s** |
| **45** | ✅ | 37.88 t/s | 4.12 t/s |
| 48 | ✅ | 35.59 t/s | 3.82 t/s |
| 50 | ✅ | 35.59 t/s | 3.82 t/s |

### Benchmark Results with Larger Context

| n-cpu-moe | Context | Prompt | Generation |
|-----------|---------|--------|------------|
| 48 | 4K | 99.04 t/s | 4.03 t/s |
| 48 | 8K | 87.85 t/s | 3.81 t/s |
| 50 | 16K | 69.44 t/s | 3.79 t/s |

### Optimal Configuration for 24GB VRAM

```
--n-cpu-moe 48 --threads 20 --flash-attn on --ctx-size 140000
```

- **--n-cpu-moe 48**: First 48 layers' experts on CPU (minimum for 140K context)
- **--threads 20**: Optimal for dual Xeon
- **--ctx-size 140000**: Maximum practical context for 24GB VRAM

### Performance Expectation
- Prompt processing: ~70-100 tok/s
- Generation: ~4 tok/s

### Comparison: Qwen3 vs M2.5

| Metric | Qwen3 (80B) | M2.5 (230B) |
|--------|-------------|-------------|
| Model size | 53GB | 69GB |
| Parameters | 80B | 230B |
| Min n-cpu-moe (128 ctx) | 29 | 43 |
| Min n-cpu-moe (140K ctx) | 40 | 48 |
| Generation speed | ~11 tok/s | ~4 tok/s |
| Prompt speed | ~190 tok/s | ~90 tok/s |

### Key Findings
1. M2.5 is **~3x slower** than Qwen3 due to 230B params vs 80B
2. M2.5 needs **more CPU offload** (48 vs 40) for same context
3. IQ2_XXS quantization is very efficient but slow
4. For 24GB VRAM, M2.5 requires n-cpu-moe >= 43 for basic use

### Server Command
```bash
/data1/data/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server \
  --device ROCm0 --gpu-layers all --ctx-size 140000 \
  --host 192.168.1.251 --port 8081 \
  --model ~/llama.cpp/models/UD-IQ2_XXS/MiniMax-M2.5-UD-IQ2_XXS-00001-of-00003.gguf \
  --threads 20 --threads-batch 10 --flash-attn on --n-cpu-moe 48 \
  --temp 1.0 --top-p 0.95 --min-p 0.01 \
  --cache-type-k q8_0 --cache-type-v q8_0 --cache-ram 32768 \
  --cache-reuse 512 --cache-prompt \
  --batch-size 2048 --ubatch-size 512 --mlock --no-mmap --kv-unified
```
