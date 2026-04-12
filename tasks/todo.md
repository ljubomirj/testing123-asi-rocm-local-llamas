# Todo

## 2026-03-26 Qwen35 Recheck

- [x] Identify the old generated-data / forced-context benchmark matrix for Qwen3.5-35B-A3B on macbook2.
- [x] Start the current llama.cpp wrapper for Qwen3.5-35B-A3B on port 8081.
- [x] Re-run the old none/small/mid/long/longlong benchmark matrix against the current wrapper configuration.
- [x] Summarize the refreshed results against the older 2026-03-01 baseline.

### Review

- Fresh rerun directory: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_162504`.
- The current wrapper launched the non-draft `SERVER_ARGS` path on `8081` with `build-macbook2-metal/bin/llama-server`, `threads=10`, `threads-batch=10`, `parallel=1`, `ctx-size=262144`, and no speculative draft model active.
- The full forced-context matrix completed with zero crashes or reloads.

## 2026-03-26 Nemotron Cascade 2 30B Recheck

- [x] Confirm the Nemotron-Cascade-2-30B-A3B model card settings relevant to llama.cpp serving on macbook2.
- [x] Add a Nemotron llama.cpp wrapper that reuses the Qwen wrapper's non-model cache/thread/context settings.
- [x] Extend the macbook benchmark harness to support assistant-prefill for Nemotron instruct-mode requests.
- [x] Start the Nemotron wrapper on port 8081 and verify instruct-mode requests succeed.
- [x] Run the thinking-off none/small/mid/long/longlong forced-context matrix and save the raw JSONL outputs.
- [x] Restart Nemotron with thinking enabled and verify the server log reports `chat template, thinking = 1`.
- [x] Run the thinking-on none/small/mid/long/longlong forced-context matrix and save the raw JSONL outputs.
- [x] Summarize the results and update repo notes.

### Review

- Thinking-off raw outputs: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_175243`
- Thinking-on raw outputs: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_181420`

## 2026-03-27 Nemotron vs Qwen Follow-up

- [x] Create a higher-level comparison note for the refreshed Qwen rerun and the two Nemotron runs on macbook2.
- [x] Record the exact llama-server launch parameters and wrapper scripts used for the good macbook2 context results.
- [x] Add a local Nemotron model alias to the LiveCodeBench harness.
- [x] Run the 92-problem LiveCodeBench subset for Nemotron using repo-local `runs/`.
- [x] Compare the Nemotron score against the incumbent Qwen `0.7717` run and summarize the result.

### Review

- First Nemotron LCB attempt matched the Qwen incumbent's `max_tokens=100000`, but it proved impractical for a thinking-mode local run: after `21m19s` only `1/36` problems had completed in window 1, with problem 2 still holding the request open.
- Replanned Nemotron LCB to use `max_tokens=16384` and `--n-predict 16384`, matching the local MiroThinker thinking-model subset cap so the benchmark can finish.
- Final Nemotron run root: `/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_20260327_100010`
- Thinking verification: `/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_20260327_100010/Nemotron-Cascade-2-30B-A3B-Q6.server.log` contains `chat template, thinking = 1`
- Final union score: `0.7717`, exactly tying the incumbent Qwen `0.7717`
- Difficulty split vs Qwen:
  - easy: Nemotron `0.9688` vs Qwen `0.9375`
  - medium: Nemotron `0.8718` vs Qwen `0.8462`
  - hard: Nemotron `0.2857` vs Qwen `0.3810`
- Runtime penalty vs Qwen: `17148s` vs `2988s`, about `5.74x` slower wall-clock

## 2026-03-27 Nemotron Thinking-Budget Follow-up

- [x] Verify the incumbent Qwen LiveCodeBench rerun token cap from local records.
- [x] Inspect the current local llama.cpp `--reasoning-budget` implementation in source and help text.
- [x] Sanity-check Nemotron with a tiny reasoning budget to confirm the forced budget message is actually injected.
- [x] Run Nemotron with thinking ON, total output `10K`, reasoning budget `4K`.
- [x] Run Nemotron with thinking OFF, total output `10K`.
- [x] Compare the two diagnostic runs against each other and against the earlier Nemotron `16K` thinking-on run.
- Thinking verification:
  - OFF log: `/Users/ljubomir/llama.cpp/log_llama-server-nemotron-ppid_28009-20260326_175047.log` contains `chat template, thinking = 0`
  - ON log: `/Users/ljubomir/llama.cpp/log_llama-server-nemotron-ppid_38255-20260326_181255.log` contains `chat template, thinking = 1`
- The thinking-on path outperformed the forced thinking-off path on every long-context band from 15K through 115K total context, and also improved throughput in the none-context runs.
- Qwen incumbent clarification: the final `0.7717` recheck used `max_tokens=10000`, not `4000`; the `4000` cap belonged to an older matrix run, and `100000` was a stale assumption.
- Budgeted Nemotron run root: `/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_thinking_on_budget4k_total10k_20260327_151310`
- Budgeted run outcome: `0.8152` overall in `8146s`, with thinking confirmed ON and repeated `reasoning-budget: budget exhausted` events in the server log.
- Thinking-OFF control root: `/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_thinking_off_total10k_20260327_172918`
- Thinking-OFF control outcome: `0.5000` overall in `1580s`; fastest wall-clock, but accuracy collapsed on medium (`0.4359`) and hard (`0.0000`).
- Compared with the earlier unbounded Nemotron thinking run (`0.7717` in `17148s`), the `10K / 4K` budgeted run was both stronger and much faster, making bounded thinking the best Nemotron operating point tested so far.

## 2026-03-28 MiniMax-M2.5 JANG_2L Smoke Test

- [x] Confirm whether `JANGQ-AI/MiniMax-M2.5-JANG_2L` needs a custom runtime beyond the local MLX stack.
- [x] Verify the cached local snapshot is complete and reuse it without re-downloading.
- [x] Run the official example locally from the cached snapshot path inside `~/python3-venv/torch313`.
- [x] Measure first-pass load / TTFT / decode speed and note whether it fits under current memory limits.
- Official sources say MiniMax JANG needs the JANG runtime and `temp=1.0`, `top_p=0.95`, `top_k=40`; plain greedy decoding is not recommended.
- The existing `torch313` venv already had a working stack: `jang 2.2.0`, `mlx 0.30.6`, `mlx-lm 0.30.7`.
- The local snapshot was complete under `/Users/ljubomir/.cache/huggingface/hub/models--JANGQ-AI--MiniMax-M2.5-JANG_2L/...`, so no download was needed.
- Local config reports `max_position_embeddings=196608`, `256` experts, `8` experts active per token, and JANG runtime weight size about `55.9 GB`.
- The model loaded successfully from the cached local path and generated output with the model-card sampler settings.
- Practical speed on macbook2 was poor: cold load about `20-31s`, warm TTFT about `5.86s`, and steady decode about `0.51-0.52 tok/s`.
- Peak memory footprint observed in the measured short run was about `67.9 GB`, so the example fit without changing `iogpu.wired_limit_mb`.

## 2026-03-28 Nemotron Q8 macbook2 Rerun

- [x] Rebuild the macbook2 Nemotron context suite for `Nemotron-Cascade-2-30B-A3B-Q8_0.gguf` using the requested `1M / 16K / 8K` thinking-on settings.
- [x] Run the full none/small/mid/long/longlong forced-context matrix under `runs/`.
- [x] Rebuild the local Nemotron LiveCodeBench launcher for the same Q8 settings.
- [x] Fix the local LiveCodeBench `LanguageModelStore` so the new Q8 alias resolves.
- [x] Run the full 92-problem union subset and compare the result against the prior Qwen and Nemotron baselines.
- Q8 context run root: `/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/context`
- Q8 context summary: `None 50 0.327s / 56.0 tok/s`, `Small 15K 12.504s / 22.3 tok/s`, `Mid 30K 14.488s / 19.9 tok/s`, `Long 50K 17.831s / 15.2 tok/s`, `Longlong 115K 41.839s / 10.1 tok/s`.
- Q8 LCB run root: `/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/livecodebench_on_budget8k_total16k`
- Q8 LCB outcome: `0.8152` overall, `75 / 92`, easy `0.9688`, medium `0.8205`, hard `0.5714`, runtime `12252s`.
- Comparison against the best earlier Nemotron Q6 budgeted run: same overall score and solved count, but Q8 was slower by `4106s` and only shifted accuracy toward hard problems.
- Comparison against the Qwen incumbent: Q8 Nemotron still beat `Qwen3.5-35B-A3B-IQ4` on overall pass@1 (`0.8152` vs `0.7717`), but took about `4.10x` the wall-clock (`12252s` vs `2988s`).
