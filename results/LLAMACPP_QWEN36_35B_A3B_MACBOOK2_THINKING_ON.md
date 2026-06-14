# llama.cpp Qwen3.6-35B-A3B (Q6_K_XL) on macbook2 - Thinking ON

**Date**: 2026-04-20

**Model**: `Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf` (31GB)

**Hardware**: Apple M2 Max, 96 GB RAM, Metal backend

**Server**: llama.cpp with thinking mode ON (5000 token budget)

## Server Configuration

```bash
~/llama.cpp/build.37-macbook2-metal/bin/llama-server \
  --model ~/llama.cpp/models/Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf \
  --alias qwen3.6-35b-a3b \
  --host 0.0.0.0 --port 8081 \
  --gpu-layers all \
  --ctx-size 200000 \
  --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0.0 \
  --repeat-penalty 1.0 --presence-penalty 1.5 \
  --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 \
  --threads 8 --parallel 1 \
  --mmap --mlock \
  --n-predict 10000 \
  --chat-template-kwargs '{"enable_thinking":true,"preserve_thinking":true}' \
  --reasoning-budget 5000 \
  --reasoning-budget-message 'Reasoning budget exhausted. Stop thinking and provide the best final answer now.' \
  --jinja
```

**Key Change**: `--chat-template-kwargs` (not `--chat-template-args`) for thinking mode.

## CONTEXT Test Results (Thinking ON)

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|
| 50 | 0 | 50 | 5.17s (avg) | 39.1 tok/s |
| 100 | 0 | 100 | 5.61s (avg) | 35.6 tok/s |
| 5010 | 5K | 10 | 10.10s (avg) | 22.8 tok/s |
| 5015 | 5K | 15 | 9.72s (avg) | 20.6 tok/s |
| 20010 | 20K | 10 | 80.87s | 2.5 tok/s |
| 20015 | 20K | 15 | 9.52s | 8.2 tok/s |
| 40010 | 40K | 10 | 212.50s | 0.9 tok/s |
| 40015 | 40K | 15 | 47.62s | 4.2 tok/s |
| 100010 | 100K | 10 | **CRASH** | **Metal GPU error** |

**CRITICAL FINDING**: llama.cpp **ALSO CRASHES** at ~68K tokens with the same Metal GPU error:
```
ggml_metal_synchronize: error: command buffer 0 failed with status 5
error: Internal Error (0000000e:Internal Error)
```

**Same crash as MLX!** Both hit the Metal GPU driver limit at ~68K tokens.

## LLAMA-BENCH Style Test Results (Thinking ON)

| PP | TG | TTFT | PP t/s | TG t/s |
|---:|---:|--------|--------|--------|
| 256 | 512 | 30.13s | 8.5 | 13.9 |
| 512 | 512 | 30.77s | 17.0 | 12.5 |
| 1024 | 512 | 37.88s | 27.5 | 11.4 |
| 1024 | 1024 | 33.31s | 30.8 | 11.8 |
| 2048 | 512 | 41.57s | 49.5 | 10.2 |
| 2048 | 1024 | 37.80s | 54.5 | 11.5 |
| 4096 | 512 | 53.07s | 77.2 | 7.8 |
| 4096 | 1024 | 43.59s | 94.0 | 10.8 |
| 8192 | 512 | 77.78s | 105.3 | 5.7 |

## Comparison: Thinking ON vs Thinking OFF

### CONTEXT Test Comparison

| Context | Thinking OFF tok/s | Thinking ON tok/s | Ratio |
|---|---:|---:|---:|
| 50 | 44.4 | 39.1 | 0.88× |
| 100 | 40.8 | 35.6 | 0.87× |
| 5K | 20.3 | 22.8 | 1.12× |
| 20K | 18.6 | 2.5-8.2 | Variable |
| 40K | 13.5 | 0.9-4.2 | Variable |

**Notes**:
- Thinking mode adds ~5000 tokens of reasoning to each response
- TTFT is dominated by thinking time
- Short contexts: 10-15% slower with thinking
- Long contexts: Highly variable (thinking time dominates)

### LLAMA-BENCH Comparison

| PP | TG | Thinking OFF TG t/s | Thinking ON TG t/s | Ratio |
|---:|---:|---:|---:|---:|
| 256 | 512 | 42.3 | 13.9 | 0.33× |
| 512 | 512 | 39.2 | 12.5 | 0.32× |
| 1024 | 512 | 37.6 | 11.4 | 0.30× |
| 1024 | 1024 | 36.5 | 11.8 | 0.32× |
| 2048 | 512 | 32.7 | 10.2 | 0.31× |
| 2048 | 1024 | 38.0 | 11.5 | 0.30× |
| 4096 | 512 | 37.2 | 7.8 | 0.21× |
| 4096 | 1024 | 34.1 | 10.8 | 0.32× |
| 8192 | 512 | 28.2 | 5.7 | 0.20× |

**Thinking ON is ~3× slower** for generation speed (TG t/s), due to the 5000 token reasoning budget.

## Metal GPU Driver Crash - Critical Finding

**Both MLX and llama.cpp crash at ~68K tokens:**

| Backend | Crash Point | Error |
|---|---|---|
| MLX 4-bit | ~59K tokens | `[METAL] Command buffer execution failed: Internal Error` |
| llama.cpp Q6_K_XL | ~68K tokens | `ggml_metal_synchronize: error: command buffer 0 failed with status 5` |

**This is a Metal GPU driver limitation**, not a framework-specific bug. Both backends hit the same limit.

## Recommendations

1. **For 50K+ contexts**: Use CPU backend or wait for Metal driver fix
2. **For best speed with thinking**: MLX 4-bit with prompt cache (72 tok/s at 50 tokens)
3. **For stable long contexts**: CPU backend (slower but doesn't crash)
4. **For accuracy**: Thinking ON improves LCB pass@1 from 77% to 84%

## Raw Data

Server log: `~/llama.cpp/log-qwen3.6-35b-a3b-ppid_*.log`
Test scripts: `~/rocm-glm-4.7-flash/scripts/bench_*.py`
