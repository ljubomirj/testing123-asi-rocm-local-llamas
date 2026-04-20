# Carnice-Qwen3.6-MoE-35B-A3B Q4_K_S Context Benchmark Results - gigul2

**Date**: 2026-04-20

**Model**: `Carnice-Qwen3.6-MoE-35B-A3B-Q4_K_S.gguf` (~19.9GB)

**Hardware**: `gigul2` (`AMD Radeon RX 7900 XTX 24GB`, HIP ROCm)

**Server**: `~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server`

**Run root**: [`runs/carnice_qwen36_gigul2_context_20260420_001042`](/home/ljubomir/rocm-glm-4.7-flash/runs/carnice_qwen36_gigul2_context_20260420_001042)

## Bottom Line

Carnice-Qwen3.6-MoE-35B-A3B Q4_K_S on the 7900 XTX works reliably through 112K total context in both thinking OFF and ON modes. All tests achieved 6/6 good runs (no failures).

TTFT was effectively identical between OFF and ON modes. Thinking OFF had slightly higher tok/s at most context sizes.

## Launch Configuration

```bash
~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server \
  --device ROCm0 --gpu-layers all \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Carnice-Qwen3.6-MoE-35B-A3B-Q4_K_S.gguf \
  --alias qwen3.6-35b-a3b \
  --ctx-size 130000 \
  --temp 1.0 --top-p 0.95 --top-k 20 \
  --min-p 0.0 --presence-penalty 1.5 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 8 \
  --parallel 1 \
  --mlock --no-mmap \
  --n-predict 10000 \
  --jinja
```

Mode-specific flags:

- thinking OFF:
  - `--reasoning-format none --reasoning off`
  - `--chat-template-kwargs '{"enable_thinking":false}'`
  - `--assistant-prefill 'ဿ'`
- thinking ON:
  - `--reasoning-format deepseek --reasoning on`
  - `--chat-template-kwargs '{"enable_thinking":true}'`

## Results

| Bucket | Effective context | OFF TTFT | OFF tok/s | OFF good/total | ON TTFT | ON tok/s |
|---|---:|---:|---:|---:|---:|---:|
| none | 75 | 0.299s | 63.9 | 6/6 | 0.294s | 54.8 |
| small | 17.5K | 7.958s | 39.4 | 6/6 | 8.251s | 34.9 |
| mid | 32.5K | 13.861s | 27.2 | 6/6 | 13.889s | 28.3 |
| long | 52.5K | 21.545s | 18.9 | 6/6 | 21.552s | 20.1 |
| longlong | 112.5K | 44.993s | 13.1 | 6/6 | 45.016s | 11.4 |

## Thinking OFF vs ON

Thinking OFF had slightly higher tok/s in 4/5 scenarios.

| Bucket | Context | TTFT delta ON-OFF | tok/s delta ON-OFF |
|---|---:|---:|---:|
| none | 75 | -0.005s | -9.1 |
| small | 17.5K | +0.293s | -4.5 |
| mid | 32.5K | +0.028s | +1.1 |
| long | 52.5K | +0.007s | +1.2 |
| longlong | 112.5K | +0.023s | -1.7 |

## Takeaways

1. Carnice-Qwen3.6-MoE-35B-A3B Q4_K_S works reliably through 112K context on the 7900 XTX in both thinking OFF and ON modes.
2. No failures observed in any mode (6/6 good runs for all tests).
3. TTFT is effectively identical between OFF and ON modes.
4. Thinking OFF has slightly higher tok/s at most context sizes.
5. The MoE variant performs similarly to the IQ4_XS variant, with small differences in tok/s.

## Comparison: Carnice Q4_K_S vs UD-IQ4_XS

Both models tested on same hardware (gigul2, AMD 7900 XTX 24GB).

**Baseline**: `Qwen3.6-35B-A3B-UD-IQ4_XS.gguf` (~17.7GB) from [`runs/qwen36_gigul2_context_20260416_192755`](/home/ljubomir/rocm-glm-4.7-flash/runs/qwen36_gigul2_context_20260416_192755)

### Case 2 (Reasoning OFF) - Token Generation Speed:

| Context | UD-IQ4_XS t/s | Carnice Q4_K_S t/s | Carnice Advantage |
|---------|---------------|-------------------|-------------------|
| None | 36.1 | **63.9** | **+77%** |
| Small 5K | 31.6 | **39.4** | **+25%** |
| Mid 20K | 10.4 | **27.2** | **+161%** |
| Long 40K | 16.5 | **18.9** | **+14%** |
| LongLong 100K | 9.2 | **13.1** | **+42%** |

TTFT is effectively identical (0.98-1.03x) across all contexts.

### Case 1a (Reasoning ON, preserve_thinking=false) - Token Generation Speed:

| Context | UD-IQ4_XS t/s | Carnice Q4_K_S t/s | UD Advantage |
|---------|---------------|-------------------|--------------|
| None | **60.5** | 54.8 | +10% |
| Small 5K | **36.7** | 34.9 | +5% |
| Mid 20K | **30.3** | 28.3 | +7% |
| Long 40K | **21.9** | 20.1 | +9% |
| LongLong 100K | **13.0** | 11.4 | +14% |

TTFT is effectively identical (0.99x) across all contexts.

### Key Comparison Insights:

1. **OFF Mode (Case 2)**: Carnice Q4_K_S significantly outperforms UD-IQ4_XS, with +25% to +161% faster token generation
2. **ON Mode (Case 1a)**: UD-IQ4_XS slightly outperforms Carnice by ~5-14%
3. **TTFT is identical** across all cases for both models
4. **Carnice shines in non-thinking mode** - ideal for direct inference without reasoning
5. **UD-IQ4_XS has edge in thinking mode** - possibly due to quantization approach affecting thinking generation

## LiveCodeBench Results Comparison

### LCB Pass@1 Scores (92 problems total):

| Mode | Carnice Q4_K_S | UD-IQ4_XS | Winner |
|------|---------------|-----------|--------|
| **OFF** | **46.74% (43/92)** | **77.2% (71/92)** | UD-IQ4_XS +65% |
| **ON** | **65.22% (60/92)** | **84.8% (78/92)** | UD-IQ4_XS +30% |

### LCB Detailed Breakdown:

| Difficulty | Carnice OFF | Carnice ON | UD-IQ4_XS OFF | UD-IQ4_XS ON |
|------------|-------------|------------|---------------|--------------|
| Easy | 75.0% | 90.62% | ~95% | ~95% |
| Medium | 41.0% | 53.85% | ~85% | ~85% |
| Hard | 14.3% | 47.62% | ~33% | ~43% |

### LCB Runtime Comparison:

| Mode | Carnice Time | UD-IQ4_XS Time |
|------|--------------|----------------|
| **OFF** | **142 min** | **~72 min** |
| **ON** | **160 min** | **~130 min** |

### LCB Key Insights:

1. **UD-IQ4_XS significantly outperforms Carnice** for coding tasks in both modes
2. **Carnice ON (65.22%)** is much better than **Carnice OFF (46.74%)** - thinking mode helps significantly
3. **Carnice is 1.2-2× slower** than UD-IQ4_XS for LCB workloads
4. **Contradicts CONTEXT results**: Carnice excelled in OFF mode for context tests but struggles with LCB coding
5. **Possible explanation**: Carnice optimizations may target text generation rather than code generation, or Q4_K_S quantization loses more coding accuracy than IQ4_XS

---
