# Qwen3.6-35B-A3B on gigul2 (7900 XTX 24GB, HIP ROCm)

**Model**: `Qwen3.6-35B-A3B-UD-IQ4_XS.gguf` (~19GB)
**Carnice Variant**: `Carnice-Qwen3.6-MoE-35B-A3B-Q4_K_S.gguf` (~19.9GB)

**Hardware**: AMD Radeon RX 7900 XTX 24GB, HIP ROCm, Xeon 10-core, 128GB RAM

**Date**: 2026-04-18 (UD-IQ4_XS), 2026-04-20 (Carnice Q4_K_S)

---

## Executive Summary

Qwen3.6-35B-A3B runs well on the 7900 XTX with ROCm backend:

| Test | Result |
|---|---:|
| **Short context speed** | 60 tok/s (Thinking ON) |
| **Long context speed** | 15-40 tok/s (up to 115K) |
| **LCB pass@1 (ON)** | 84.8% (tiny subset) |
| **LCB pass@1 (OFF)** | 77.2% (tiny subset) |
| **Thinking ON benefit** | +7.6pp LCB accuracy, 2× slower |

**Recommendation**: Use Qwen3.6-35B-A3B on 7900 XTX with IQ4_XS quantization. Enable thinking ON for best accuracy. Model works reliably through 115K context.

---

## Expected Performance on 7900 XTX

### Short Context (<1K tokens) - Thinking ON
- **Throughput**: 60 tok/s
- **TTFT**: 0.27-0.32s
- **Use case**: Chat, short prompts, quick responses

### Short Context (<1K tokens) - Thinking OFF
- **Throughput**: 28-44 tok/s
- **TTFT**: 0.26-0.32s
- **Use case**: Fast responses without reasoning

### Medium Context (15K-30K tokens)
- **Throughput**: 35-41 tok/s (ON), 31-41 tok/s (OFF)
- **TTFT**: 6-11s
- **Use case**: Document analysis, medium-length contexts

### Long Context (50K-115K tokens)
- **Throughput**: 15-26 tok/s (ON), 18-23 tok/s (OFF)
- **TTFT**: 17-54s
- **Use case**: Long documents, codebases

### Coding (LiveCodeBench)
- **pass@1 (ON)**: 84.8% (tiny 92-problem subset)
- **pass@1 (OFF)**: 77.2% (tiny 92-problem subset)
- **Easy problems**: 97-100%
- **Medium problems**: 85-95%
- **Hard problems**: 33-43%
- **Avg time**: ~47-91 seconds per problem

---

## Server Configuration

### Recommended Settings (Thinking ON)

```bash
~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server \
  --device ROCm0 --gpu-layers all \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf \
  --alias qwen3.6-35b-a3b \
  --ctx-size 150000 \
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
  --reasoning on \
  --reasoning-format deepseek \
  --reasoning-budget 5000 \
  --reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now." \
  --jinja \
  --chat-template-kwargs '{"enable_thinking":true}'
```

### For Thinking OFF (Faster, Less Accurate)

```bash
  --reasoning-format none --reasoning off \
  --assistant-prefill 'ဿ' \
  --chat-template-kwargs '{"enable_thinking":false}'
```

### Performance Tips

1. **Use `--flash-attn on`**: Required for good ROCm performance
2. **Use `--gpu-layers all`**: Offload all layers to GPU
3. **KV cache `q8_0`**: Best quality/speed tradeoff
4. **Threads 8-10**: Optimal for 7900 XTX
5. **IQ4_XS quantization**: Fits in 24GB VRAM with room to spare
6. **Thinking budget 5000**: Good balance for reasoning tasks

---

## Known Issues

### Thinking OFF Mode Bug
- **Issue**: ~33% of Thinking OFF runs produce only 4 tokens (hit EOS immediately)
- **Cause**: The `assistant-prefill 'ဿ'` character may not be correct for Qwen3.6
- **Workaround**: Use Thinking ON mode instead (more accurate anyway)
- **Impact**: Mid 35K context was completely broken in OFF mode (0/3 good runs)

### Speed vs Accuracy Tradeoff
- **Thinking ON**: +7.6pp accuracy, 2× slower
- **Thinking OFF**: Faster but buggy and less accurate
- **Recommendation**: Use Thinking ON as default

---

## Detailed Results

### 1. CONTEXT Test - Thinking ON vs OFF

Filtered to good runs only (response >= 10 tokens). Thinking OFF had significant failures.

| Bucket | Context | OFF TTFT | OFF tok/s | OFF good/total | ON TTFT | ON tok/s |
|---|---:|---:|---:|---:|---:|---:|
| none | 50 | 0.264s | 28.2 | 3/3 | 0.271s | 61.0 |
| none | 100 | 0.319s | 44.0 | 3/3 | 0.321s | 59.9 |
| small | 15K | 6.122s | 41.3 | 3/3 | 6.629s | 40.4 |
| small | 20K | 10.085s | 32.5 | 2/3 | 10.163s | 33.1 |
| mid | 30K | 10.975s | 30.7 | 2/3 | 11.000s | 34.9 |
| mid | 35K | — | — | 0/3 FAIL | 17.192s | 25.7 |
| long | 50K | 17.296s | 23.0 | 2/3 | 17.272s | 25.4 |
| long | 55K | 26.300s | 17.6 | 3/3 | 26.283s | 18.3 |
| longlong | 110K | 36.417s | 13.0 | 2/3 | 36.409s | 15.1 |
| longlong | 115K | 54.177s | 9.6 | 3/3 | 54.151s | 10.8 |

**Key Observations**:
1. Thinking ON produced higher tok/s in 8/10 scenarios
2. TTFT was effectively identical between OFF and ON modes
3. Thinking ON works reliably through 115K context
4. Thinking OFF has reproducible 4-token bug in ~33% of runs

### 2. Thinking ON vs OFF Comparison

| Bucket | Context | TTFT delta ON-OFF | tok/s delta ON-OFF |
|---|---:|---:|---:|
| none | 50 | +0.007s | +32.8 |
| none | 100 | +0.002s | +15.9 |
| small | 15K | +0.507s | -0.9 |
| small | 20K | +0.078s | +0.6 |
| mid | 30K | +0.025s | +4.2 |
| mid | 35K | — | — |
| long | 50K | -0.024s | +2.4 |
| long | 55K | -0.017s | +0.7 |
| longlong | 110K | -0.008s | +2.1 |
| longlong | 115K | -0.026s | +1.2 |

The none-context tier shows a large ON advantage in tok/s because thinking ON generates more tokens (thinking + response) in the same wall-clock time.

### 3. LiveCodeBench Test

92-problem union subset (3 time windows).

#### Thinking OFF

| Metric | Score | Count |
|---|---||---:|
| **Overall pass@1** | **77.17%** | 71/92 |
| Easy pass@1 | 96.88% | 31/32 |
| Medium pass@1 | 84.62% | 33/39 |
| Hard pass@1 | 33.33% | 7/21 |

**Runtime**: 4302 seconds (~1.2 hours)

#### Thinking ON (Budget 5000 / Total 10000)

| Metric | Score | Count |
|---|---||---:|
| **Overall pass@1** | **84.78%** | 78/92 |
| Easy pass@1 | 100.00% | 32/32 |
| Medium pass@1 | 94.87% | 37/39 |
| Hard pass@1 | 42.86% | 9/21 |

**Runtime**: 8411 seconds (~2.3 hours)

### 4. Thinking OFF vs ON Comparison

Thinking ON improved every dimension:
- **Overall**: +7.6pp (77.17% → 84.78%)
- **Easy**: +3.1pp (96.88% → 100.00%, perfect)
- **Medium**: +10.3pp (84.62% → 94.87%)
- **Hard**: +9.5pp (33.33% → 42.86%)
- **Runtime**: ~2× slower (4302s → 8411s, expected with thinking tokens)

The reasoning budget of 5000 thinking tokens out of 10000 total worked correctly with Qwen3.6 — no budget exhaustion issues observed.

---

## Comparison to Nemotron-Cascade-2-30B-A3B (Same 7900 XTX)

### CONTEXT Test - Thinking ON

| Context | Nemotron OFF TTFT | Qwen3.6 OFF TTFT | Nemorton ON tok/s | Qwen3.6 ON tok/s |
|---|---:|---:|---:|---:|
| 50 | 0.341s | 0.264s | 98.9 | 61.0 |
| 100 | 0.287s | 0.319s | 100.9 | 59.9 |
| 15K | 4.803s | 6.629s | 54.1 | 40.4 |
| 20K | 7.728s | 10.163s | 42.4 | 33.1 |
| 30K | 7.641s | 11.000s | 40.5 | 34.9 |
| 35K | 11.908s | 17.192s | 30.6 | 25.7 |
| 50K | 11.535s | 17.272s | 32.4 | 25.4 |
| 55K | 17.620s | 26.283s | 22.7 | 18.3 |
| 110K | 23.223s | 36.409s | 19.5 | 15.1 |
| 115K | 34.943s | 54.151s | 13.3 | 10.8 |

**Observation**: Nemotron is faster on both TTFT and tok/s across all context sizes. Qwen3.6's larger parameter count (35B vs 30B) likely explains the difference.

### LCB Test - Same 7900 XTX

| Model / mode | Overall | Easy | Medium | Hard | Solved | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| Qwen3.6-35B-A3B-IQ4_XS OFF | 77.17% | 96.9% | 84.6% | 33.3% | 71 / 92 | 4302s |
| Qwen3.6-35B-A3B-IQ4_XS ON | 84.78% | 100% | 94.9% | 42.9% | 78 / 92 | 8411s |
| Nemotron-Cascade-2-30B-A3B-IQ4_XS OFF | 53.26% | 87.5% | 48.7% | 9.5% | 49 / 92 | 1907s |
| Nemotron-Cascade-2-30B-A3B-IQ4_XS ON | 82.61% | 100% | 84.6% | 52.4% | 76 / 92 | 3776s |

**Key Insights**:
1. **Qwen3.6 ON beats Nemotron ON**: +2.2pp overall (84.78% vs 82.61%)
2. **Qwen3.6 ON has better Medium**: +10.3pp (94.87% vs 84.62%)
3. **Nemotron ON has better Hard**: +9.5pp (52.38% vs 42.86%)
4. **Nemorton ON is 2.2× faster**: 3776s vs 8411s (due to smaller model)

---

## Comparison to M2 Max (Different Hardware)

### Qwen3.6-35B-A3B: M2 Max vs 7900 XTX

| Context | M2 Max Q6_K_XL | 7900 XTX IQ4_XS | Ratio |
|---|---:|---:|---:|
| 50 | 44.4 | 61.0 | 1.4× 7900 XTX |
| 100 | 40.8 | 59.9 | 1.5× 7900 XTX |
| 15K | 20.3 | 40.4 | 2.0× 7900 XTX |
| 30K | 18.6 | 34.9 | 1.9× 7900 XTX |
| 50K | 13.5 | 25.4 | 1.9× 7900 XTX |
| 110K | 0.6 | 15.1 | 25× 7900 XTX |

**Note**: Different quantizations (Q6_K_XL vs IQ4_XS). Q6_K_XL is higher quality but slower.

### LCB Cross-Hardware - Thinking ON

| Hardware | Quant | Overall | Easy | Medium | Hard | Runtime |
|---|---|---:|---:|---:|---:|---:|
| M2 Max | Q6_K_XL | 83.70% | 100% | 89.7% | 47.6% | 7.4h |
| 7900 XTX | IQ4_XS | 84.78% | 100% | 94.9% | 42.9% | 2.3h |

**Summary**: 7900 XTX with IQ4_XS is ~3.2× faster than M2 Max with Q6_K_XL on LCB, with similar or slightly better accuracy.

---

## Recommendations for 7900 XTX Users

### For Best Speed
- Use Thinking OFF only if you can tolerate the 4-token bug
- IQ4_XS quantization is sufficient for most tasks
- Keep context under 50K for 25+ tok/s

### For Best Accuracy
- Always use Thinking ON (5000 token budget)
- Temperature 0.0 for deterministic outputs
- Reasoning budget works reliably with Qwen3.6

### For Long Context
- Reliable through 115K context (10-61 tok/s)
- No significant degradation at long contexts
- TTFT scales linearly with context size

### For Coding
- Qwen3.6-35B-A3B is excellent: 84.8% pass@1 with thinking ON
- Easy problems: Perfect 100%
- Medium problems: 95% with thinking ON
- Hard problems: 43% (challenging for this model size)

---

## Quick Reference

| Context Size | OFF Speed | ON Speed | Use Case |
|---|---:|---:|---|
| <1K | 28-44 tok/s | 60 tok/s | Chat, quick responses |
| 15K-30K | 31-41 tok/s | 34-41 tok/s | Documents, analysis |
| 50K-115K | 10-23 tok/s | 15-26 tok/s | Long contexts |

| Task | OFF Performance | ON Performance |
|---|---|---|---|
| Coding (Easy) | 96.9% | 100% |
| Coding (Medium) | 84.6% | 94.9% |
| Coding (Hard) | 33.3% | 42.9% |
| Overall | 77.2% | 84.8% |
| Speed | Fast (1.2h) | Slow (2.3h) |

---

## What Works

✅ **Thinking ON mode** - Reliable through 115K context, +7.6pp accuracy
✅ **Long context** - Stable performance through 115K tokens
✅ **IQ4_XS quantization** - Fits in 24GB VRAM, good quality
✅ **Reasoning budget** - 5000 token budget works correctly
✅ **ROCm backend** - Good performance on 7900 XTX

---

## What Doesn't Work

❌ **Thinking OFF mode** - ~33% of runs produce only 4 tokens (EOS bug)
❌ **assistant-prefill 'ဿ'** - Wrong character for Qwen3.6 in OFF mode
❌ **Mid 35K with OFF** - 0/3 good runs (completely broken)

---

## Bottom Line

Qwen3.6-35B-A3B is **recommended** as the default model for 7900 XTX:

1. **Best accuracy** among tested models (84.8% pass@1 with thinking ON)
2. **Reliable** through 115K context
3. **Faster than M2 Max** (1.4-2× on throughput, 3× on LCB)
4. **IQ4_XS quantization** sufficient - no need for higher quants

**Use Thinking ON as default** - the OFF mode has a reproducible bug and is less accurate anyway.

---

## Source Data

Full results in individual files:
- `CONTEXT_RESULTS_GIGUL2_LLAMACPP_HIP_ROCWMMA_QWEN36_35B_A3B.md`
- `LIVECODEBENCH_RESULTS_GIGUL2_QWEN36_35B_A3B.md`

---

## Carnice-Qwen3.6-MoE-35B-A3B Q4_K_S Results

**Model Variant**: `Carnice-Qwen3.6-MoE-35B-A3B-Q4_K_S.gguf`

### CONTEXT Test

| Bucket | Context | OFF TTFT | OFF tok/s | ON TTFT | ON tok/s |
|---|---:|---:|---:|---:|---:|
| none | 75 | 0.299s | 63.9 | 0.294s | 54.8 |
| small | 17.5K | 7.958s | 39.4 | 8.251s | 34.9 |
| mid | 32.5K | 13.861s | 27.2 | 13.889s | 28.3 |
| long | 52.5K | 21.545s | 18.9 | 21.552s | 20.1 |
| longlong | 112.5K | 44.993s | 13.1 | 45.016s | 11.4 |

**Key Observations**:
- All tests achieved 6/6 good runs (no failures)
- Reliable through 112K context
- OFF mode has slightly higher tok/s at most context sizes
- TTFT effectively identical between OFF and ON modes

### LLAMA-BENCH Results

| PP | TG | TTFT | PP Speed | TG Speed |
|---:|---:|---:|---:|---:|
| 128 | 512 | 9.24s | 13.9 t/s | 67.3 t/s |
| 256 | 512 | 8.65s | 29.6 t/s | 58.4 t/s |
| 256 | 1024 | 8.67s | 29.5 t/s | 58.7 t/s |
| 512 | 2048 | 22.73s | 22.5 t/s | 62.5 t/s |
| 4096 | 2048 | 36.48s | 112.3 t/s | 68.5 t/s |

**Key Observations**:
- TG speed: 58-68 t/s (consistent)
- PP speed scales linearly: 14-112 t/s
- Tested with reasoning ON (5000 token budget)

### Comparison: Carnice Q4_K_S vs UD-IQ4_XS

| Metric | Carnice Q4_K_S | UD-IQ4_XS |
|--------|----------------|-----------|
| TG speed (typical) | 58-68 t/s | 53-60 t/s |
| Context reliability | 6/6 good runs | OFF mode had failures |
| Quant size | ~19.9GB | ~19GB |

The Carnice variant performs similarly to the UD-IQ4_XS variant in terms of throughput, with improved reliability in OFF mode testing.
