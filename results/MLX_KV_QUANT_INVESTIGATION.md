# MLX KV Cache Quantization Investigation - Qwen3.6-35B-A3B on macbook2

**Date**: 2026-04-20

**Purpose**: Investigate if KV cache quantization (`--kv-bits 8` or `--kv-bits 3.5 TurboQuant`) can prevent the 100K context Metal GPU crash.

## Summary

**Result**: KV cache quantization is **NOT available** for `mlx_lm.server` with text-only models.

## Investigation Details

### Attempt 1: Check mlx_lm.server for KV quant flags

```bash
mlx_lm.server --help
```

**Finding**: `mlx_lm.server` does NOT expose `--kv-bits` or `--kv-quant-scheme` flags.

Available flags:
- `--model`, `--host`, `--port`
- `--max-tokens`, `--chat-template-args`
- `--prompt-cache-size`, `--prompt-cache-bytes`
- `--decode-concurrency`, `--prompt-concurrency`
- NO `--kv-bits`, `--kv-quant-scheme`, `--kv-group-size`

### Attempt 2: Check mlx_lm source code

**Finding**: No KV cache quantization support in `mlx_lm` package (version 0.31.3).

```python
from mlx_lm import cache  # FAILS - no cache module
from mlx_lm.utils import load
# load() parameters: path_or_hf_repo, tokenizer_config, model_config,
#                    adapter_path, lazy, return_config, revision
# NO kv_bits, kv_quant_scheme, etc.
```

### Attempt 3: Try mlx_vlm.server (has KV quant support)

**Command**:
```bash
mlx_vlm.server \
  --model mlx-community/Qwen3.6-35B-A3B-4bit \
  --trust-remote-code \
  --port 8081 \
  --kv-bits 8 \
  --kv-quant-scheme uniform
```

**Result**: Server starts but model inference FAILS with:
```
TypeError: Qwen3_5MoeDecoderLayer.__call__() got an unexpected keyword argument 'gdn_sink'
```

**Root Cause**: `mlx_vlm` and `mlx_lm` have **different model implementations**:
- `mlx_vlm/models/qwen3_5/language.py`: Has `gdn_sink` parameter (for VLM models)
- `mlx_lm/models/qwen3_5/`: Different implementation, NO `gdn_sink`

They are **incompatible** - `mlx_vlm.server` cannot run `mlx_lm` text-only models.

### Attempt 4: Check for environment variable support

**Finding**: No evidence that setting `KV_BITS` environment variable affects `mlx_lm.server`. KV quantization requires code-level support in the cache implementation.

## Conclusion

| Approach | Status | Reason |
|---|---|---|
| `mlx_lm.server --kv-bits` | **NOT SUPPORTED** | Flag doesn't exist |
| Environment variables | **NOT SUPPORTED** | No code implementation |
| `mlx_vlm.server --kv-bits` | **INCOMPATIBLE** | Different model implementations |

## Why KV Quantization Doesn't Help Here

The Metal GPU crash at 100K context is a **driver/kernel issue**, not a memory issue:
- Error: `[METAL] Command buffer execution failed: Internal Error (0000000e:Internal Error)`
- Happens at ~59K tokens during prefill
- NOT an out-of-memory error

KV cache quantization reduces memory usage but **doesn't fix driver bugs**.

## Alternative: 50K Context Cap

Since KV quantization isn't available, the practical solution is to **cap contexts at 50K**:

| Context | MLX 4-bit (no KV quant) |
|---|---:|
| <1K | 65-72 tok/s (excellent) |
| 5K | 42 tok/s (good) |
| 20K | 2-4 tok/s (slow) |
| 50K | 1.5-2 tok/s (very slow) |
| 100K | CRASH |

## Recommendations

1. **For production use on M2 Max**: Use `llama.cpp Q6_K_XL` for contexts >20K
2. **For chat/short contexts**: Use `mlx_lm.server` with prompt cache enabled
3. **For 100K+ contexts**: `llama.cpp` only (MLX crashes)

## Files

- `scripts/bench_context_50k.py` - CONTEXT test with 50K cap
- `scripts/bench_llama_style.py` - PP/TG matrix test

## Next Steps

Wait for:
1. MLX framework update to fix Metal GPU crash at 100K
2. mlx-lm to add KV cache quantization support
3. Or mlx_vlm/mlx_lm model implementation convergence
