# MACBOOK2: Gemma 4 26B-A4B Unsloth UD-Q8_K_XL on llama.cpp Metal

**Date**: 2026-04-10

**Machine**: macbook2, Apple M2 Max, 96 GB RAM

**Live server model**: `gemma-4-26B-A4B-it-UD-Q8_K_XL.gguf`

**Alias**: `gemma-4-26b-a4b-it`

**Run root**: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310`

## Setup

These results were taken against the already-running server on `127.0.0.1:8081`.

Observed live server command:

```bash
/Users/ljubomir/llama.cpp/build-macbook2-metal/bin/llama-server \
  --gpu-layers all \
  --host 127.0.0.1 --port 8081 \
  --model /Users/ljubomir/llama.cpp/models/gemma-4-26B-A4B-it-UD-Q8_K_XL.gguf \
  --alias gemma-4-26b-a4b-it \
  --ctx-size 262144 \
  --temp 1.0 --top-p 0.95 --top-k 64 --min-p 0.0 \
  --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 1 \
  --mlock --mmap \
  --n-predict 16384 \
  --reasoning on \
  --reasoning-format deepseek \
  --reasoning-budget 8192 \
  --reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now." \
  --jinja \
  --spec-type ngram-mod \
  --spec-ngram-size-n 24 \
  --draft-min 48 \
  --draft-max 64
```

Important benchmark note:

- All requests were sent with `chat_template_kwargs={"enable_thinking": true}`.
- This report is intentionally a thinking-on Gemma 4 run, end to end.
- `ngram-mod` speculative decoding was active on this model. The server log showed real draft generation and acceptance, unlike Nemotron-Cascade-2 where speculative decoding was rejected outright.

## CONTEXT

**Benchmark script**: `/Users/ljubomir/rocm-glm-4.7-flash/bench_longcontext_macbook.py`

**Request mode**:

- `chat_template_kwargs={"enable_thinking": true}`
- `runs=3`
- none-context: `max_tokens=200`
- forced-context bands: `max_tokens=512`

**Raw files**:

- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/context/benchmark_gemma4_26b_a4b_unsloth_thinking_none_macbook2.jsonl`
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/context/benchmark_gemma4_26b_a4b_unsloth_thinking_small_5k_macbook2.jsonl`
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/context/benchmark_gemma4_26b_a4b_unsloth_thinking_mid_20k_macbook2.jsonl`
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/context/benchmark_gemma4_26b_a4b_unsloth_thinking_long_40k_macbook2.jsonl`
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/context/benchmark_gemma4_26b_a4b_unsloth_thinking_longlong_100k_macbook2.jsonl`
- runner log: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/context/benchmark_runner.log`

### Context Summary

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.518s | 33.5 tok/s |
| 100 | 0 | 100 | 0.434s | 33.5 tok/s |
| 15K | 5K | 10K | 13.355s | 12.8 tok/s |
| 20K | 5K | 15K | 22.112s | 11.0 tok/s |
| 30K | 20K | 10K | 17.393s | 9.4 tok/s |
| 35K | 20K | 15K | 27.762s | 9.3 tok/s |
| 50K | 40K | 10K | 23.229s | 6.9 tok/s |
| 55K | 40K | 15K | 44.731s | 4.9 tok/s |
| 110K | 100K | 10K | 47.583s | 3.5 tok/s |
| 115K | 100K | 15K | 66.717s | 3.4 tok/s |

### Context Readout

- Empty-context baseline is weaker than the earlier ggml-org Gemma 4 report: about `33.5 tok/s` rather than about `40 tok/s`.
- At moderate context, the Unsloth run is mixed: slightly better at `20K`, roughly tied around `30K..50K`, and worse at `55K`.
- At very long context, the Unsloth run is slower than the earlier ggml-org run: `3.5 tok/s` at `110K` and `3.4 tok/s` at `115K`.
- Deep-context variance was high. The server log showed speculative draft acceptance was active but unstable at `110K+`, including low-acceptance streak resets.

### Context Comparison To Prior Gemma 4 Report

Reference report:

- `/Users/ljubomir/rocm-glm-4.7-flash/MACBOOK2_GEMMA4_26B_A4B.md`

| Total context | ggml-org Q8_0, non-thinking | Unsloth UD-Q8_K_XL, thinking on |
|---|---:|---:|
| 50 | 40.0 tok/s | 33.5 tok/s |
| 100 | 37.1 tok/s | 33.5 tok/s |
| 15K | 14.1 tok/s | 12.8 tok/s |
| 20K | 10.2 tok/s | 11.0 tok/s |
| 30K | 9.3 tok/s | 9.4 tok/s |
| 35K | 8.2 tok/s | 9.3 tok/s |
| 50K | 6.9 tok/s | 6.9 tok/s |
| 55K | 5.5 tok/s | 4.9 tok/s |
| 110K | 3.6 tok/s | 3.5 tok/s |
| 115K | 3.2 tok/s | 3.4 tok/s |

Context bottom line:

- The Unsloth quant does not show a clear speed win over the earlier ggml-org Gemma 4 run on this machine.
- It is slower at short context, roughly similar through part of the midrange, and not materially better at the far end.
- The biggest difference versus the earlier report may be request mode: this run kept thinking on throughout, and the deep-context speculative acceptance was unstable.

## LCB

**Benchmark script**: `/Users/ljubomir/rocm-glm-4.7-flash/scripts/livecodebench_run_subset.sh`

**Request mode**:

- `MAX_TOKENS=10000`
- `TEMP=0.0`
- `TOP_P=1.0`
- `N=1`
- `OPENAI_TIMEOUT=1800`
- `LCB_CHAT_TEMPLATE_KWARGS_JSON={"enable_thinking": true}`

**Raw outputs**:

- run dir: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/livecodebench/gemma-4-26b-a4b-it`
- union score: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/livecodebench/gemma-4-26b-a4b-it/scores_union_three_windows.txt`
- `2024-01-01 .. 2024-02-29`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/livecodebench/gemma-4-26b-a4b-it/scores_2024-01-01_to_2024-02-29.txt`
- `2024-05-01 .. 2024-06-30`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/livecodebench/gemma-4-26b-a4b-it/scores_2024-05-01_to_2024-06-30.txt`
- `2025-04-01 .. 2025-05-31`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_unsloth_thinking_macbook2_20260410_090310/livecodebench/gemma-4-26b-a4b-it/scores_2025-04-01_to_2025-05-31.txt`

### LCB Summary

**Union of three windows (92 problems)**:

- overall `0.2065`
- easy `0.3750` (`32`)
- medium `0.1795` (`39`)
- hard `0.0000` (`21`)
- solved `19 / 92`
- runtime `40045s`

### Per-window Scores

| Window | Problems | Pass@1 | Easy | Medium | Hard | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| 2024-01-01 .. 2024-02-29 | 36 | 0.1667 | 0.3077 | 0.1053 | 0.0000 | 16427s |
| 2024-05-01 .. 2024-06-30 | 44 | 0.2500 | 0.4375 | 0.2222 | 0.0000 | 18835s |
| 2025-04-01 .. 2025-05-31 | 12 | 0.1667 | 0.3333 | 0.5000 | 0.0000 | 4783s |

### LCB Comparison To Prior Gemma 4 Report

Reference report:

- `/Users/ljubomir/rocm-glm-4.7-flash/MACBOOK2_GEMMA4_26B_A4B.md`

| Model / mode | Overall | Easy | Medium | Hard | Solved | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| Gemma 4 ggml-org Q8_0, non-thinking requests | 0.8804 | 1.0000 | 0.9231 | 0.6190 | 81 / 92 | 9139s |
| Gemma 4 Unsloth UD-Q8_K_XL, thinking on | 0.2065 | 0.3750 | 0.1795 | 0.0000 | 19 / 92 | 40045s |

LCB bottom line:

- This Unsloth thinking-on configuration was dramatically worse for LiveCodeBench than the earlier ggml-org non-thinking Gemma 4 run.
- It solved only `19 / 92` problems and scored `0.0000` on hard problems.
- Runtime also exploded to `40045s`, far slower than the earlier `9139s`.

## Bottom Line

- For **context speed**, the Unsloth `UD-Q8_K_XL` file is not an obvious win on macbook2. It is slower at small context, only roughly competitive across parts of the midrange, and still poor at very long context.
- For **coding quality**, this exact configuration was bad: `0.2065` overall on the 92-problem LiveCodeBench subset, versus `0.8804` for the earlier ggml-org Gemma 4 report.
- The likely issue is not merely “Gemma 4 is bad.” The stronger explanation is the operating point: thinking-on plus unstable speculative acceptance appears to be a poor combination for this benchmark on this quant.
