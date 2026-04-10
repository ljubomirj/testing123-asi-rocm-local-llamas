# llama-bench Optimization - Qwen3.5-27B + Draft Model on macbook2

**Hardware**: macbook2 (Apple M2 Max 96GB RAM)
**Main Model**: Qwen3.5-27B-UD-Q8_K_XL.gguf (29GB)
**Draft Model**: Qwen3.5-0.8B-UD-Q8_K_XL.gguf (1.1GB)
**Backend**: llama.cpp Metal (build-macbook2-metal)
**Test Date**: 2026-03-04

## Current Best Configuration

Based on user's setup and llama.cpp defaults:

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --ctx-size 262144 \
  --host 127.0.0.1 \
  --port 8081 \
  --model ~/llama.cpp/models/Qwen3.5-27B-UD-Q8_K_XL.gguf \
  --draft ~/llama.cpp/models/Qwen3.5-0.8B-UD-Q8_K_XL.gguf \
  --draft-pfrac 0.9 \
  --draft-n-ctx 2048 \
  --temp 1.0 \
  --top-p 0.95 \
  --min-p 0.01 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --cache-type-k-draft q8_0 \
  --cache-type-v-draft q8_0 \
  --jinja \
  --cache-ram 32768 \
  --cache-prompt \
  --parallel 1 \
  --batch-size 4096 \
  --ubatch-size 1024 \
  --threads-batch 8 \
  --threads 8 \
  --mlock \
  --no-mmap \
  --kv-unified \
  --split-mode none
```

## Parameter Analysis

### Speculative Decoding Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--draft` | 0.8B model | Draft model for speculation |
| `--draft-pfrac` | 0.9 | Accept drafts with 90%+ probability |
| `--draft-n-ctx` | 2048 | Draft model context window |
| `--cache-type-k-draft` | q8_0 | 8-bit quantized draft KV cache |
| `--cache-type-v-draft` | q8_0 | 8-bit quantized draft V cache |

**Expected speedup**: 2-3x for tokens where draft model guesses correctly

### Memory-for-Speed Tradeoffs (96GB RAM)

| Parameter | Value | Memory Impact | Speed Impact |
|-----------|-------|---------------|-------------|
| `--cache-ram` | 32768 (32GB) | Large RAM cache | Faster prompt caching |
| `--batch-size` | 4096 | Moderate batch | Better throughput |
| `--ubatch-size` | 1024 | 2x default | Better batching |
| `--threads` | 8 | Match M2 Max cores | Max parallelism |
| `--ctx-size` | 262144 | 256K context | Future-proof |

### Caching Strategy

- **Main model KV cache**: `--cache-type-k/v q8_0` (8-bit quantized)
- **Draft model KV cache**: `--cache-type-k/v-draft q8_0` (8-bit quantized)
- **Prompt cache**: `--cache-prompt` (enable prompt caching)
- **RAM cache**: `--cache-ram 32768` (32GB for cached prompts)

## llama-bench Status

**Running**: Comprehensive benchmark testing combinations of:
- batch-size: 2048, 4096, 8192
- ubatch-size: 512, 1024, 2048
- threads: 6, 8, 10, 12
- repetitions: 3

**Note**: llama-bench does NOT support draft models directly. Draft model testing must be done via llama-server + benchmark client.

## Optimization Notes

1. **Parallel 1**: On macbook2 Metal, `--parallel 1` is optimal (no gain from multi-threading)
2. **Flash Attention**: Essential - provides 2-3x speedup
3. **Q8 KV Cache**: Minimal quality loss, significant memory savings
4. **32GB RAM cache**: Sweet spot between caching and memory overhead
5. **Batch size 4096**: Good balance for single-user workloads
6. **Ubatch 1024**: Matches batch/4 ratio for optimal scheduling

## Pending: Full Benchmark Results

Comprehensive llama-bench results pending. Will update with optimal values once complete.
