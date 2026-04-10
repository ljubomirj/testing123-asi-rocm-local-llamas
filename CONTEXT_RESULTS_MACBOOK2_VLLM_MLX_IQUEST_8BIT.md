# IQuest-Coder-V1-14B-Thinking 8-bit Benchmark Results - vLLM-MLX

**Model**: IQuest-Coder-V1-14B-Thinking-MLX-8bit (14GB)
**Hardware**: macbook2 (Apple M2 Max 96GB RAM)
**Backend**: vLLM-MLX (MLX framework)
**Test Date**: 2026-03-04

## Server Configuration

```bash
vllm-mlx serve models/IQuest-Coder-V1-14B-Thinking-MLX-8bit \
    --port 8081 \
    --reasoning-parser qwen3 \
    --enable-auto-tool-choice \
    --tool-call-parser qwen \
    --use-paged-cache \
    --paged-cache-block-size 128 \
    --max-cache-blocks 2000 \
    --kv-cache-quantization \
    --kv-cache-quantization-bits 4 \
    --chunked-prefill-tokens 2048 \
    --cache-memory-percent 0.30
```

## Results Summary

### None Context (No Prefill)

| Context | TTFT  | Throughput |
|---------|-------|------------|
| 50      | 3.10s | 16.8 tok/s |
| 100     | 6.37s | 16.0 tok/s |

### Context Tests with Prefill

| Context | Prefill | TTFT | Throughput | Status |
|---------|---------|------|------------|--------|
| 15K     | 5K      | N/A  | N/A        | **Server crashed** |
| 20K     | 5K      | N/A  | N/A        | **Server crashed** |
| 30K     | 20K     | N/A  | N/A        | **Server crashed** |
| 35K     | 20K     | N/A  | N/A        | **Server crashed** |
| 50K     | 40K     | N/A  | N/A        | **Server crashed** |
| 55K     | 40K     | N/A  | N/A        | **Server crashed** |
| 110K    | 100K    | N/A  | N/A        | **Server crashed** |
| 115K    | 100K    | N/A  | N/A        | **Server crashed** |

## Key Findings

1. **Severe context limitation**: vLLM-MLX crashes at contexts >10K tokens
   - Server exits with code 134 (SIGABRT) or 139 (SIGSEGV)
   - Likely MLX Metal backend limitation or memory issue

2. **Slow baseline performance**: 16 tok/s is much slower than llama.cpp GGUF
   - IQuest 14B 8-bit: ~16 tok/s
   - Qwen 35B-A3B Q8 (llama.cpp): ~28 tok/s
   - GLM 4.7-Flash Q4 (llama.cpp): ~85 tok/s

3. **Optimizations tested** (no improvement):
   - `--use-paged-cache`
   - `--kv-cache-quantization` (4-bit)
   - `--chunked-prefill-tokens`
   - Increased cache memory to 30%

4. **Practical limit**: ~10K tokens for vLLM-MLX with this model

## Comparison to llama.cpp on Same Hardware

| Backend | Model | Baseline | Max Context |
|---------|-------|----------|-------------|
| vLLM-MLX | IQuest 14B 8-bit | 16 tok/s | ~10K |
| llama.cpp Metal | Qwen 35B-A3B Q8 | 28 tok/s | 115K |
| llama.cpp Metal | GLM 4.7-Flash Q4 | 85 tok/s | 190K |

## Conclusion

**vLLM-MLX is not suitable for long-context inference** on this model/hardware combination:
- Crashes at contexts >10K tokens
- 2-5x slower baseline than llama.cpp
- For production use, llama.cpp with GGUF models is far superior

The advantage of vLLM-MLX is its tool calling and reasoning parser support, but for raw inference performance and context handling, llama.cpp is clearly superior.
