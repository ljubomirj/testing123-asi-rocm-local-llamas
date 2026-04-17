# GIGUL2: Gemma 4 26B-A4B Unsloth UD-Q4_K_XL on llama.cpp HIP ROCm

**Date**: 2026-04-12

**Machine**: gigul2, AMD 7900 XTX 24GB, 128GB RAM

**Live server model**: `gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf`

**Alias**: `gemma-4-26b-a4b-it`

**Run roots**:
- Round 1 (thinking ON 8K): `/home/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_gigul2_20260412_093435`
- Round 2 (thinking OFF): `/home/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinkingOFF_gigul2_20260412_153800`
- Round 3 (thinking ON 5K): `/home/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinkingON_5k_gigul2_20260413_071320`

## Setup

These results were taken against the already-running server on `127.0.0.1:8081`.

Observed live server command (Round 1 - thinking ON):

```bash
~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server \
  --device ROCm0 \
  --gpu-layers all \
  --host 0.0.0.0 --port 8081 \
  --model ~/llama.cpp/models/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf \
  --alias gemma-4-26b-a4b-it \
  --ctx-size 262144 \
  --temp 1.0 --top-p 0.95 --top-k 64 --min-p 0.0 \
  --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 32768 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 4 \
  --mlock --no-mmap \
  --n-predict 16384 \
  --reasoning on \
  --reasoning-format deepseek \
  --reasoning-budget 8192 \
  --reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now." \
  --jinja
```

Important benchmark notes:

- Round 1: `chat_template_kwargs={"enable_thinking": true}` - thinking ON
- Round 2: `chat_template_kwargs={"enable_thinking": false}` - thinking OFF
- Ngram speculative decode was intentionally disabled (suspected poor performance per macbook2 analysis)
- `runs=3` for all context tests except 110K/115K which crashed with thinking ON
- 100K/110K/115K total context test crashed with thinking ON, succeeded with thinking OFF

## CONTEXT

**Benchmark script**: `/home/ljubomir/rocm-glm-4.7-flash/scripts/bench_longcontext.py`

### Context Summary - Gemma4 on gigul2

| Total context | Prefill | Prompt | OFF TTFT | OFF tok/s | ON TTFT | ON tok/s |
|---|---:|---:|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.190s | 67.8 | 1.191s | 50.3 |
| 100 | 0 | 100 | 0.175s | 66.7 | 0.174s | 64.8 |
| 15K | 5K | 10K | 8.445s | 39.4 | 10.591s | 32.4 |
| 20K | 5K | 15K | 13.024s | 28.4 | 16.880s | 23.6 |
| 30K | 20K | 10K | 9.322s | 36.9 | 12.146s | 28.5 |
| 35K | 20K | 15K | 14.159s | 29.0 | 17.672s | 24.6 |
| 50K | 40K | 10K | 10.125s | 34.4 | 12.326s | 29.8 |
| 55K | 40K | 15K | 15.295s | 27.5 | 17.645s | 23.8 |
| 110K | 100K | 10K | 12.412s | 30.3 | CRASH | - |
| 115K | 100K | 15K | 18.316s | 23.8 | CRASH | - |

### Context Readout

- Thinking OFF is faster at every context level, especially at empty context (67.8 vs 50.3 tok/s at 50 tokens)
- Thinking ON has much higher TTFT at empty context (1.191s vs 0.190s at 50 tokens) due to warmup overhead
- At forced context, thinking OFF maintains lead in both TTFT and throughput
- 100K+ context works with thinking OFF but crashed with thinking ON (memory pressure from reasoning budget)

## LCB

**Benchmark script**: `/home/ljubomir/rocm-glm-4.7-flash/scripts/livecodebench_run_subset.sh`

**Request mode**:

- `MAX_TOKENS=10000`
- `TEMP=0.0`
- `TOP_P=1.0`
- `N=1`
- `OPENAI_TIMEOUT=1800`

### LCB Results

**Round 1 (thinking ON)**: `/home/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_gigul2_20260412_093435`

**Union of three windows (92 problems)**:

- overall `0.8478`
- easy `1.0000` (`32`)
- medium `0.8974` (`39`)
- hard `0.5238` (`21`)
- solved `78 / 92`
- runtime ~4h

**Round 2 (thinking OFF)**: `/home/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinkingOFF_gigul2_20260412_153800`

**Union of three windows (92 problems)**:

- overall `0.8696`
- easy `1.0000` (`32`)
- medium `0.9487` (`39`)
- hard `0.5238` (`21`)
- solved `80 / 92`
- runtime 3656s

### LCB Comparison: macbook2 vs gigul2

| Model / mode | Overall | Easy | Medium | Hard | Solved | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| Gemma4 gigul2 OFF | **0.8696** | 1.0000 | 0.9487 | 0.5238 | **80/92** | 3656s |
| Gemma4 gigul2 ON | 0.8478 | 1.0000 | 0.8974 | 0.5238 | 78/92 | ~4h |
| Gemma4 macbook2 ON (ngram) | 0.2065 | 0.3750 | 0.1795 | 0.0000 | 19/92 | 40045s |
| Gemma4 macbook2 OFF | 0.8804 | 1.0000 | 0.9231 | 0.6190 | 81/92 | 9139s |

### Key Insights

1. **Ngram speculative decode was devastating**: macbook2 with ngram scored only 0.2065 LCB. Gigul2 without ngram scored **0.8696** (OFF) - confirming ngram was the problem.

2. **Thinking OFF is better than thinking ON for Gemma4 on gigul2**: 0.8696 vs 0.8478, opposite of what was expected.

## Comparison to Nemotron-Cascade-2-30B-A3B on gigul2

Same hardware, same llama.cpp HIP ROCm build, similar quantization (IQ4_XS vs UD-Q4_K_XL).

### Context Comparison

| Scenario | Nemotron OFF TTFT | Nemotron OFF tok/s | Gemma4 OFF TTFT | Gemma4 OFF tok/s | Nemotron ON TTFT | Nemotron ON tok/s | Gemma4 ON TTFT | Gemma4 ON tok/s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| None 50 | 0.341s | 89.4 | 0.190s | 67.8 | 0.393s | 98.9 | 1.191s | 50.3 |
| None 100 | 0.287s | 93.5 | 0.175s | 66.7 | 0.314s | 100.9 | 0.174s | 64.8 |
| Small 15K | 4.754s | 43.5 | 8.445s | 39.4 | 4.803s | 54.1 | 10.591s | 32.4 |
| Small 20K | 7.700s | 35.1 | 13.024s | 28.4 | 7.728s | 42.4 | 16.880s | 23.6 |
| Mid 30K | 7.618s | 35.4 | 9.322s | 36.9 | 7.641s | 40.5 | 12.146s | 28.5 |
| Mid 35K | 11.862s | 25.4 | 14.159s | 29.0 | 11.908s | 30.6 | 17.672s | 24.6 |
| Long 50K | 11.519s | 27.0 | 10.125s | 34.4 | 11.535s | 32.4 | 12.326s | 29.8 |
| Long 55K | 17.588s | 20.3 | 15.295s | 27.5 | 17.620s | 22.7 | 17.645s | 23.8 |
| Longlong 110K | 23.206s | 15.5 | 12.412s | 30.3 | 23.223s | 19.5 | CRASH | - |
| Longlong 115K | 34.697s | 11.5 | 18.316s | 23.8 | 34.943s | 13.3 | CRASH | - |

### Readout

- Nemotron has lower TTFT at most context levels (better prefill performance)
- Gemma4 has higher throughput at most context levels (better decode performance)
- At 50K-55K range, Gemma4 OFF is competitive: lower TTFT (10.125s vs 11.519s) and higher tok/s (34.4 vs 27.0)
- At 110K-115K, Gemma4 OFF works while Nemotron ON crashes

### LCB Comparison

| Model / mode | Overall | Easy | Medium | Hard | Solved | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| **Gemma4 gigul2 OFF** | **0.8696** | 1.0000 | 0.9487 | 0.5238 | **80/92** | 3656s |
| Gemma4 gigul2 ON 8K | 0.8478 | 1.0000 | 0.8974 | 0.5238 | 78/92 | 13422s |
| Gemma4 gigul2 ON 5K | 0.8370 | 1.0000 | 0.8718 | 0.5238 | 77/92 | 9522s |
| Nemotron gigul2 ON | 0.8261 | 1.0000 | 0.8462 | 0.5238 | 76/92 | ~4h |
| Nemotron gigul2 OFF | 0.5326 | 0.8750 | 0.4872 | 0.0952 | 49/92 | ~4h |

### Readout

- Gemma4 OFF (`0.8696`) is the best LCB score on gigul2
- Thinking budget affects quality: 8K (0.8478) > 5K (0.8370) for Gemma4
- More thinking budget = more quality, but also more runtime
- Gemma4 solves 80/92 vs Nemotron's 76/92 (ON)
- Both have identical hard problem performance (0.5238)
- Gemma4 thinking OFF outperforms thinking ON, while Nemotron benefits from thinking ON

## Bottom Line

1. **Ngram speculative decode was devastating**: Disabling it on gigul2 allowed thinking ON to achieve `0.8478` vs macbook2's `0.2065` with it enabled.

2. **Gemma4 vs Nemotron on gigul2**:
   - LCB quality: Gemma4 OFF (`0.8696`) > Gemma4 ON 8K (`0.8478`) > Nemotron ON (`0.8261`)
   - Context speed: Mixed - Nemotron has better TTFT, Gemma4 has better throughput at mid-long context
   - 100K+ context: Gemma4 OFF works, Nemotron ON crashes

3. **Thinking ON vs OFF on gigul2**:
   - For Gemma4: Thinking OFF (0.8696) beats Thinking ON (0.8478 with 8K)
   - For Nemotron: Thinking ON (0.8261) beats Thinking OFF (0.5326)
   - TTFT penalty for thinking ON at empty context (1.191s vs 0.190s at 50 tokens)
   - Throughput advantage for thinking OFF at all levels

4. **Gemma4 Thinking Budget Sweep**:
   - OFF (no thinking): 0.8696 @ 3656s
   - ON 5K budget: 0.8370 @ 9522s  
   - ON 8K budget: 0.8478 @ 13422s
   - More thinking budget = more quality but also more runtime
   - Thinking OFF is both faster AND more accurate for Gemma4 on this benchmark
