# Nemotron-Cascade-2-30B-A3B on llama.cpp Metal (macbook2)

**Date**: 2026-03-26

**Machine**: macbook2, Apple M2 Max, 96 GB RAM

**Model**: `/Users/ljubomir/llama.cpp/models/Nemotron-Cascade-2-30B-A3B.Q6_K.gguf`

**Sampling from model card**:
- `temperature = 1.0`
- `top_p = 0.95`
- Chat format from the card is ChatML

**Shared llama.cpp server settings**:
- `ctx-size 262144`
- `flash-attn on`
- `cache-type-k q8_0`
- `cache-type-v q8_0`
- `kv-unified`
- `cache-prompt`
- `cache-ram 16384`
- `cache-reuse 512`
- `batch-size 2048`
- `ubatch-size 512`
- `threads 10`
- `threads-batch 10`
- `parallel 1`
- `mlock`
- `no-mmap`

## Thinking-Off Run

**Wrapper**: `/Users/ljubomir/llama.cpp/run_llama_nemotron_cascade_2_wrapper_macbook2.sh`

**Mode details**:
- Server flags: `--reasoning-format none --reasoning off`
- Request path: assistant-prefill `<think></think>`
- Request kwargs: `chat_template_kwargs={"enable_thinking":false}`

**Verification**:
- `/Users/ljubomir/llama.cpp/log_llama-server-nemotron-ppid_28009-20260326_175047.log` contains `srv          init: init: chat template, thinking = 0`

**Raw outputs**:
- Directory: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_175243`
- Runner log: [/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_175243/benchmark_runner.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_175243/benchmark_runner.log)

## Thinking-On Run

**Wrapper**: `/Users/ljubomir/llama.cpp/run_llama_nemotron_cascade_2_thinking_wrapper_macbook2.sh`

**Mode details**:
- Server flags: `--reasoning-format deepseek --reasoning on`
- No assistant-prefill override

**Verification**:
- `/Users/ljubomir/llama.cpp/log_llama-server-nemotron-ppid_38255-20260326_181255.log` contains `srv          init: init: chat template, thinking = 1`
- A sanity request returned both `message.content` and `message.reasoning_content`

**Raw outputs**:
- Directory: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_181420`
- Runner log: [/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_181420/benchmark_runner.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_181420/benchmark_runner.log)

## Summary

| Scenario | Thinking OFF TTFT | Thinking ON TTFT | Thinking OFF tok/s | Thinking ON tok/s |
|---|---:|---:|---:|---:|
| None 50 | 0.267s | 0.318s | 49.7 | 57.7 |
| None 100 | 0.493s | 0.495s | 43.1 | 52.4 |
| Small 15K | 13.291s | 11.980s | 18.2 | 23.3 |
| Small 20K | 20.061s | 18.556s | 14.7 | 16.9 |
| Mid 30K | 15.021s | 14.045s | 16.1 | 21.4 |
| Mid 35K | 22.539s | 21.056s | 12.6 | 15.5 |
| Long 50K | 18.863s | 17.100s | 13.8 | 16.4 |
| Long 55K | 27.923s | 25.792s | 10.7 | 12.8 |
| Longlong 110K | 29.240s | 27.656s | 9.5 | 10.6 |
| Longlong 115K | 41.580s | 40.725s | 7.5 | 9.5 |

## Notes

- Thinking ON improved throughput in every measured scenario.
- Thinking ON also improved TTFT in every forced-context band from 15K through 115K total context.
- The only TTFT regression was the empty 50-token case, where thinking ON was slightly slower (`0.318s` vs `0.267s`), but still decoded faster.
- Both runs completed with zero crashes.

## 2026-03-28 Q8 Thinking-On Rerun

**Model**: `/Users/ljubomir/llama.cpp/models/Nemotron-Cascade-2-30B-A3B-Q8_0.gguf`

**Run root**: `/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context`

**Shared server settings**:
- `ctx-size 1048576`
- `temp 1.0`
- `top_p 0.95`
- `top_k 0`
- `min_p 0.0`
- `presence-penalty 0.0`
- `repeat-penalty 1.0`
- `flash-attn on`
- `cache-type-k q8_0`
- `cache-type-v q8_0`
- `kv-unified`
- `cache-prompt`
- `cache-ram 16384`
- `cache-reuse 512`
- `batch-size 2048`
- `ubatch-size 512`
- `threads 10`
- `threads-batch 10`
- `parallel 1`
- `mlock`
- `mmap`
- `n-predict 16384`
- `reasoning on`
- `reasoning-format deepseek`
- `reasoning-budget 8192`
- `reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now."`
- `jinja`

**Verification**:
- `/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/llama-server-thinking-on.log` contains `chat template, thinking = 1`
- the same log contains `reasoning-budget: activated, budget=8192 tokens`

**Raw outputs**:
- Runner log: [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_runner.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_runner.log)
- None: [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_none_wrapper_10t_thinking_on.jsonl](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_none_wrapper_10t_thinking_on.jsonl)
- Small: [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_small_5k_wrapper_10t_thinking_on.jsonl](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_small_5k_wrapper_10t_thinking_on.jsonl)
- Mid: [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_mid_20k_wrapper_10t_thinking_on.jsonl](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_mid_20k_wrapper_10t_thinking_on.jsonl)
- Long: [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_long_wrapper_10t_thinking_on.jsonl](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_long_wrapper_10t_thinking_on.jsonl)
- Longlong: [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_longlong_100k_wrapper_10t_thinking_on.jsonl](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context/benchmark_nemotron_cascade_2_30b_q8_longlong_100k_wrapper_10t_thinking_on.jsonl)

### Q6 vs Q8, Both Thinking ON

| Scenario | Q6 ON TTFT | Q8 ON TTFT | Q6 ON tok/s | Q8 ON tok/s |
|---|---:|---:|---:|---:|
| None 50 | 0.318s | 0.327s | 57.7 | 56.0 |
| None 100 | 0.495s | 0.464s | 52.4 | 50.0 |
| Small 15K | 11.980s | 12.504s | 23.3 | 22.3 |
| Small 20K | 18.556s | 21.121s | 16.9 | 15.5 |
| Mid 30K | 14.045s | 14.488s | 21.4 | 19.9 |
| Mid 35K | 21.056s | 21.518s | 15.5 | 15.1 |
| Long 50K | 17.100s | 17.831s | 16.4 | 15.2 |
| Long 55K | 25.792s | 26.312s | 12.8 | 14.1 |
| Longlong 110K | 27.656s | 28.246s | 10.6 | 11.4 |
| Longlong 115K | 40.725s | 41.839s | 9.5 | 10.1 |

### Readout

- Q8 did not improve TTFT on the forced-context matrix in any meaningful way. It was slightly better only on the empty `100`-token case, and otherwise matched or trailed the earlier Q6 thinking-on run.
- Decode throughput was mixed, but Q8 was not clearly better overall. It lost on the short and mid bands, then recovered a bit on the heaviest long-context points.
- The practical takeaway from this context rerun is that Q8 did not buy a speed win on macbook2 Metal. Any reason to prefer it would have to come from quality, not context-speed behavior.
