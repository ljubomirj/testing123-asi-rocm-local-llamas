# LiveCodeBench: Qwen35 vs Nemotron Variants on macbook2

**Date**: 2026-03-27

## Compared Runs

- Qwen incumbent recheck: `/Users/ljubomir/rocm-glm-4.7-flash/benchmark_results_livecodebench_qwen35b_recheck_20260315_171139`
- Nemotron thinking ON, unbounded, total `16384`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_20260327_100010`
- Nemotron thinking ON, total `10000`, reasoning budget `4096`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_thinking_on_budget4k_total10k_20260327_151310`
- Nemotron thinking OFF, total `10000`: `/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_thinking_off_total10k_20260327_172918`

## Bottom Line

The practical local sweet spot for `Nemotron-Cascade-2-30B-A3B-Q6` is not thinking OFF, and it is not unbounded thinking. It is bounded thinking.

On this 92-problem subset:

- `Qwen3.5-35B-A3B-IQ4` incumbent: `0.7717` in `2988s`
- `Nemotron` thinking ON, unbounded `16384`: `0.7717` in `17148s`
- `Nemotron` thinking ON, total `10000`, budget `4096`: `0.8152` in `8146s`
- `Nemotron` thinking OFF, total `10000`: `0.5000` in `1580s`

So the `4096`-token thinking budget inside a `10000`-token total cap improved Nemotron in both directions that matter:

- higher accuracy than the incumbent Qwen and the earlier unbounded Nemotron run
- much lower runtime than the earlier unbounded Nemotron run

## Token-Cap Clarification

The incumbent Qwen recheck that scored `0.7717` used `max_tokens=10000`, not `4000`.

- The `4000` cap belongs to an older matrix run.
- The `100000` cap was an earlier assumption that turned out to be wrong for the final incumbent recheck.
- The first Nemotron attempt at `100000` was therefore chasing the wrong target and proved impractical anyway.

## Score Summary

| Model / mode | Thinking | Total cap | Thinking budget | Overall | Easy | Medium | Hard | Runtime |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Qwen3.5-35B-A3B-IQ4 | OFF | 10000 | n/a | 0.7717 | 0.9375 | 0.8462 | 0.3810 | 2988s |
| Nemotron-Cascade-2-30B-A3B-Q6 | ON | 16384 | unbounded | 0.7717 | 0.9688 | 0.8718 | 0.2857 | 17148s |
| Nemotron-Cascade-2-30B-A3B-Q6 | ON | 10000 | 4096 | 0.8152 | 1.0000 | 0.8462 | 0.4762 | 8146s |
| Nemotron-Cascade-2-30B-A3B-Q6 | OFF | 10000 | n/a | 0.5000 | 0.9062 | 0.4359 | 0.0000 | 1580s |

Solved counts over the 92-problem union:

- Qwen incumbent: `71 / 92`
- Nemotron ON `16384`: `71 / 92`
- Nemotron ON `10000 / 4096`: `75 / 92`
- Nemotron OFF `10000`: `46 / 92`

## Readout

- Thinking OFF is only a speed shortcut. It collapses medium and hard performance too far to be a serious contender.
- Unbounded thinking was not buying enough accuracy to justify its wall-clock cost.
- Bounded thinking fixed that tradeoff well enough to beat both prior baselines.

The most important shift is on hard problems:

- Qwen incumbent hard: `0.3810`
- Nemotron ON `16384` hard: `0.2857`
- Nemotron ON `10000 / 4096` hard: `0.4762`
- Nemotron OFF `10000` hard: `0.0000`

That is the best evidence that the reasoning-budget mechanism is helping Nemotron rather than merely truncating it.

## Runtime Readout

- Budgeted Nemotron vs unbounded Nemotron: `8146s` vs `17148s`
- Runtime reduction: `-9002s`
- Relative runtime: budgeted run took about `0.48x` as long

- Budgeted Nemotron vs Qwen incumbent: `8146s` vs `2988s`
- Nemotron still took about `2.73x` the Qwen wall-clock time

- Thinking-OFF Nemotron vs Qwen incumbent: `1580s` vs `2988s`
- Thinking-OFF Nemotron was faster, but the quality loss was severe enough that this is not a good operating point

## Reasoning-Budget Evidence

The current local `llama.cpp` reasoning-budget implementation is active and working on Nemotron.

- Thinking ON confirmed in the budgeted run log: [Nemotron-Cascade-2-30B-A3B-Q6.server.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_thinking_on_budget4k_total10k_20260327_151310/Nemotron-Cascade-2-30B-A3B-Q6.server.log#L229)
- Thinking OFF confirmed in the control run log: [Nemotron-Cascade-2-30B-A3B-Q6.server.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_thinking_off_total10k_20260327_172918/Nemotron-Cascade-2-30B-A3B-Q6.server.log#L228)
- Budget exhaustion fired repeatedly in the budgeted run: [Nemotron-Cascade-2-30B-A3B-Q6.server.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_thinking_on_budget4k_total10k_20260327_151310/Nemotron-Cascade-2-30B-A3B-Q6.server.log#L249)

So this was not a placebo run. The sampler really was forcing the end of reasoning when the thought budget was spent.

## Exact llama-server Parameters

Nemotron launchers:

- parameterized variant script: [livecodebench_run_nemotron_variant.sh](/Users/ljubomir/rocm-glm-4.7-flash/scripts/livecodebench_run_nemotron_variant.sh)
- earlier unbounded script: [livecodebench_run_nemotron_subset.sh](/Users/ljubomir/rocm-glm-4.7-flash/scripts/livecodebench_run_nemotron_subset.sh)

Common Nemotron `llama-server` flags across the three Nemotron LCB runs:

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Nemotron-Cascade-2-30B-A3B.Q6_K.gguf \
  --alias Nemotron-Cascade-2-30B-A3B-Q6 \
  --ctx-size 150000 \
  --temp 0.0 --top-p 1.0 --top-k 0 --min-p 0.0 \
  --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 1 \
  --mlock --no-mmap \
  --jinja
```

Variant deltas:

- unbounded thinking run:
```bash
--reasoning-format deepseek --reasoning on --n-predict 16384
```

- budgeted thinking run:
```bash
--reasoning-format deepseek --reasoning on \
--reasoning-budget 4096 \
--reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now." \
--n-predict 10000
```

- thinking-OFF control:
```bash
--reasoning-format none --reasoning off --n-predict 10000
```

The subset runner side was deterministic in all cases:

```bash
MAX_TOKENS=<same as n-predict> TEMP=0.0 TOP_P=1.0 N=1
```

## Qwen Incumbent Parameters

The final incumbent `Qwen3.5-35B-A3B-IQ4` subset recheck used the same deterministic benchmark recipe:

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Qwen3.5-35B-A3B-UD-IQ4_XS.gguf \
  --alias Qwen3.5-35B-A3B-IQ4 \
  --ctx-size 150000 \
  --temp 0.0 --top-p 1.0 --top-k 0 --min-p 0.0 \
  --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 1 \
  --mlock --no-mmap \
  --reasoning-format auto --reasoning-budget -1 \
  --n-predict 10000 \
  --jinja --reasoning off \
  --chat-template-kwargs '{"enable_thinking":false}'
```

## Conclusion

If the goal is the strongest local Nemotron operating point tested so far on this subset, the winner is:

- thinking ON
- total output cap `10000`
- reasoning budget `4096`

That run beat the current local Qwen incumbent on overall pass@1 while avoiding the worst runtime blow-up from unbounded thinking.

## 2026-03-28 Q8 Rerun

**Run root**: `/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/livecodebench_on_budget8k_total16k`

**Model**: `Nemotron-Cascade-2-30B-A3B-Q8`

**Budget / cap**:
- thinking `ON`
- total cap `16384`
- reasoning budget `8192`

**Exact launch record**:
- [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/livecodebench_on_budget8k_total16k/launch.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/livecodebench_on_budget8k_total16k/launch.log)

**Verification**:
- [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/livecodebench_on_budget8k_total16k/Nemotron-Cascade-2-30B-A3B-Q8.server.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/livecodebench_on_budget8k_total16k/Nemotron-Cascade-2-30B-A3B-Q8.server.log) contains `chat template, thinking = 1`
- the same server log contains `reasoning-budget: activated, budget=8192 tokens`

**Union score file**:
- [/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/livecodebench_on_budget8k_total16k/Nemotron-Cascade-2-30B-A3B-Q8/scores_union_three_windows.txt](/Users/ljubomir/rocm-glm-4.7-flash/runs/nemotron_macbook2_q8_suite_20260328_233027/livecodebench_on_budget8k_total16k/Nemotron-Cascade-2-30B-A3B-Q8/scores_union_three_windows.txt)

### Updated Score Summary

| Model / mode | Thinking | Total cap | Thinking budget | Overall | Easy | Medium | Hard | Solved | Runtime |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Qwen3.5-35B-A3B-IQ4 | OFF | 10000 | n/a | 0.7717 | 0.9375 | 0.8462 | 0.3810 | 71 / 92 | 2988s |
| Nemotron-Cascade-2-30B-A3B-Q6 | ON | 16384 | unbounded | 0.7717 | 0.9688 | 0.8718 | 0.2857 | 71 / 92 | 17148s |
| Nemotron-Cascade-2-30B-A3B-Q6 | ON | 10000 | 4096 | 0.8152 | 1.0000 | 0.8462 | 0.4762 | 75 / 92 | 8146s |
| Nemotron-Cascade-2-30B-A3B-Q6 | OFF | 10000 | n/a | 0.5000 | 0.9062 | 0.4359 | 0.0000 | 46 / 92 | 1580s |
| Nemotron-Cascade-2-30B-A3B-Q8 | ON | 16384 | 8192 | 0.8152 | 0.9688 | 0.8205 | 0.5714 | 75 / 92 | 12252s |

### Q6 Budgeted vs Q8 Budgeted Readout

- The Q8 rerun matched the best earlier Nemotron overall score exactly: `0.8152` and `75 / 92`.
- It did not improve solved count over the Q6 budgeted run.
- It was slower by `4106s`: `12252s` vs `8146s`, about `1.50x` the wall-clock.
- The score shape shifted:
  - Q6 budgeted was better on easy and medium.
  - Q8 budgeted was materially better on hard: `0.5714` vs `0.4762`.

### Per-window Q8 Scores

- `2024-01-01 .. 2024-02-29` (36 problems): `0.7778`, runtime `4786s`
- `2024-05-01 .. 2024-06-30` (44 problems): `0.9545`, runtime `4503s`
- `2025-04-01 .. 2025-05-31` (12 problems): `0.4167`, runtime `2963s`

### Exact Q8 llama-server Parameters

From the recorded launch log:

```bash
/Users/ljubomir/llama.cpp/build-macbook2-metal/bin/llama-server \
  --host 127.0.0.1 --port 8081 \
  --model /Users/ljubomir/llama.cpp/models/Nemotron-Cascade-2-30B-A3B-Q8_0.gguf \
  --alias Nemotron-Cascade-2-30B-A3B-Q8 \
  --ctx-size 1048576 \
  --temp 1.0 --top-p 0.95 --top-k 0 --min-p 0.0 \
  --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 1 \
  --mlock --mmap \
  --reasoning-format deepseek --reasoning on \
  --reasoning-budget 8192 \
  --reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now." \
  --n-predict 16384 \
  --jinja
```

### Current Bottom Line

- Q8 did not beat the best earlier Nemotron operating point on overall subset score.
- Q8 did not beat it on solved count.
- Q8 did cost substantially more wall-clock.

So the best local Nemotron operating point on macbook2 still remains the earlier Q6 bounded-thinking run:

- thinking `ON`
- total cap `10000`
- reasoning budget `4096`
