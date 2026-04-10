# MACBOOK2: Gemma 4 26B A4B on llama.cpp Metal

**Date**: 2026-04-10

**Machine**: macbook2, Apple M2 Max, 96 GB RAM

**Live server model**: `gemma-4-26B-A4B-it-Q8_0.gguf`

**Alias**: `gemma-4-26b-a4b-it`

**Run root**: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858`

## Setup

These results were taken against the already-running server on `127.0.0.1:8081`.

Observed live server command:

```bash
/Users/ljubomir/llama.cpp/build-macbook2-metal/bin/llama-server \
  --gpu-layers all \
  --host 127.0.0.1 --port 8081 \
  --model /Users/ljubomir/llama.cpp/models/gemma-4-26B-A4B-it-Q8_0.gguf \
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

- Both benchmark suites explicitly sent `chat_template_kwargs={"enable_thinking": false}` at request time.
- So these results are a non-thinking request path on top of the current live server.

## CONTEXT

**Benchmark script**: `/Users/ljubomir/rocm-glm-4.7-flash/bench_longcontext_macbook.py`

**Request mode**:

- `chat_template_kwargs={"enable_thinking": false}`
- `runs=3`
- none-context: `max_tokens=200`
- forced-context bands: `max_tokens=512`

**Raw files**:

- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/context/benchmark_gemma4_26b_a4b_none_macbook2.jsonl`
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/context/benchmark_gemma4_26b_a4b_small_5k_macbook2.jsonl`
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/context/benchmark_gemma4_26b_a4b_mid_20k_macbook2.jsonl`
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/context/benchmark_gemma4_26b_a4b_long_40k_macbook2.jsonl`
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/context/benchmark_gemma4_26b_a4b_longlong_100k_macbook2.jsonl`
- runner log: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/context/benchmark_runner.log`

### Context Summary

| Total context | Prefill | Prompt | TTFT | Throughput |
|---|---:|---:|---:|---:|
| 50 | 0 | 50 | 0.458s | 40.0 tok/s |
| 100 | 0 | 100 | 0.500s | 37.1 tok/s |
| 15K | 5K | 10K | 13.721s | 14.1 tok/s |
| 20K | 5K | 15K | 21.330s | 10.2 tok/s |
| 30K | 20K | 10K | 18.105s | 9.3 tok/s |
| 35K | 20K | 15K | 28.060s | 8.2 tok/s |
| 50K | 40K | 10K | 24.210s | 6.9 tok/s |
| 55K | 40K | 15K | 37.424s | 5.5 tok/s |
| 110K | 100K | 10K | 44.240s | 3.6 tok/s |
| 115K | 100K | 15K | 65.158s | 3.2 tok/s |

### Context Readout

- Empty-context baseline is strong for this size class: about `40 tok/s` at 50 tokens.
- Forced-context decay is smooth and stable: `14.1 tok/s` at 15K, `6.9 tok/s` at 50K, `3.2 tok/s` at 115K.
- The full matrix completed with zero crashes.

### Context Comparison To Prior macbook2 Runs

| Model | 50 tok baseline | 50K TTFT | 50K tok/s | 115K TTFT | 115K tok/s |
|---|---:|---:|---:|---:|---:|
| Gemma 4 26B-A4B Q8 | 40.0 | 24.21s | 6.9 | 65.16s | 3.2 |
| Qwen3.5-35B-A3B Q8 rerun | 39.0 | 19.87s | 13.3 | 49.21s | 6.9 |
| Nemotron-Cascade-2-30B-A3B Q8 | 56.0 | 17.83s | 15.2 | 41.84s | 10.1 |
| Qwen3.5-27B dense Q8 | 6.8 | 83.36s | 3.1 | 160.14s | 2.0 |

Context bottom line:

- Gemma 4 26B-A4B is vastly better than the old dense `Qwen3.5-27B` Q8 baseline on macbook2.
- It is roughly tied with the refreshed `Qwen3.5-35B-A3B` rerun on tiny-prompt baseline.
- It is clearly slower than the best local MoE incumbents once active context gets large.

## LCB

**Benchmark script**: `/Users/ljubomir/rocm-glm-4.7-flash/scripts/livecodebench_run_subset.sh`

**Request mode**:

- `MAX_TOKENS=10000`
- `TEMP=0.0`
- `TOP_P=1.0`
- `N=1`
- `OPENAI_TIMEOUT=1800`
- `LCB_CHAT_TEMPLATE_KWARGS_JSON={"enable_thinking": false}`

**Raw outputs**:

- run dir: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/livecodebench/gemma-4-26b-a4b-it`
- union score: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/livecodebench/gemma-4-26b-a4b-it/scores_union_three_windows.txt`
- `2024-01-01 .. 2024-02-29`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/livecodebench/gemma-4-26b-a4b-it/scores_2024-01-01_to_2024-02-29.txt`
- `2024-05-01 .. 2024-06-30`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/livecodebench/gemma-4-26b-a4b-it/scores_2024-05-01_to_2024-06-30.txt`
- `2025-04-01 .. 2025-05-31`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/gemma4_macbook2_20260409_223858/livecodebench/gemma-4-26b-a4b-it/scores_2025-04-01_to_2025-05-31.txt`

### LCB Summary

**Union of three windows (92 problems)**:

- overall `0.8804`
- easy `1.0000` (`32`)
- medium `0.9231` (`39`)
- hard `0.6190` (`21`)
- solved `81 / 92`
- runtime `9139s`

### Per-window Scores

| Window | Problems | Pass@1 | Easy | Medium | Hard | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| 2024-01-01 .. 2024-02-29 | 36 | 0.8611 | 1.0000 | 0.8947 | 0.2500 | 2977s |
| 2024-05-01 .. 2024-06-30 | 44 | 0.9545 | 1.0000 | 0.9444 | 0.9000 | 2483s |
| 2025-04-01 .. 2025-05-31 | 12 | 0.6667 | 1.0000 | 1.0000 | 0.4286 | 3679s |

### LCB Comparison To Prior macbook2 Runs

| Model / mode | Overall | Easy | Medium | Hard | Solved | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| Gemma 4 26B-A4B Q8, non-thinking requests | 0.8804 | 1.0000 | 0.9231 | 0.6190 | 81 / 92 | 9139s |
| Qwen3.5-35B-A3B-IQ4 incumbent | 0.7717 | 0.9375 | 0.8462 | 0.3810 | 71 / 92 | 2988s |
| Nemotron Q6, thinking ON, budget 4096 | 0.8152 | 1.0000 | 0.8462 | 0.4762 | 75 / 92 | 8146s |
| Nemotron Q8, thinking ON, budget 8192 | 0.8152 | 0.9688 | 0.8205 | 0.5714 | 75 / 92 | 12252s |

LCB bottom line:

- This Gemma run is the best macbook2 LiveCodeBench score currently recorded in this repo.
- It beats the prior Qwen incumbent by `+0.1087` overall pass@1 and `+10` solved problems.
- It beats the best earlier Nemotron operating points by `+0.0652` overall and `+6` solved problems.
- It is slower than the Qwen incumbent, but faster than the Nemotron Q8 rerun.

## Bottom Line

- For **context speed**, Gemma 4 26B-A4B Q8 is a strong local model, but not the fastest long-context MoE already tested here.
- For **LiveCodeBench quality**, this run is excellent: `0.8804`, `81 / 92`, with especially strong hard-problem performance at `0.6190`.
- If the goal is **best local coding quality on macbook2 from the currently tested set**, this Gemma run is now the top result in the repo.
