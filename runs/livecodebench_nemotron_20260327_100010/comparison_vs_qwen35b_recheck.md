# Nemotron-Cascade-2-30B-A3B-Q6 vs Qwen3.5-35B-A3B-IQ4

Comparison target:
- local run: `Nemotron-Cascade-2-30B-A3B-Q6`
- reference run: `Qwen3.5-35B-A3B-IQ4`

Source runs:
- Nemotron: `/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_20260327_100010`
- Qwen: `/Users/ljubomir/rocm-glm-4.7-flash/benchmark_results_livecodebench_qwen35b_recheck_20260315_171139`

## Setup

Nemotron launcher:
- [livecodebench_run_nemotron_subset.sh](/Users/ljubomir/rocm-glm-4.7-flash/scripts/livecodebench_run_nemotron_subset.sh)
- llama-server log confirms thinking ON:
  - [Nemotron-Cascade-2-30B-A3B-Q6.server.log](/Users/ljubomir/rocm-glm-4.7-flash/runs/livecodebench_nemotron_20260327_100010/Nemotron-Cascade-2-30B-A3B-Q6.server.log#L229)

Important caveat:
- First Nemotron attempt used `max_tokens=100000` based on an earlier assumption about the Qwen budget and proved impractical for a local thinking-model run.
- The completed Nemotron run used `max_tokens=16384` and `--n-predict 16384`.
- The final Qwen incumbent recheck actually used `max_tokens=10000` with thinking OFF.

## Overall

`Nemotron-Cascade-2-30B-A3B-Q6` matched the incumbent `Qwen3.5-35B-A3B-IQ4` exactly on the 92-problem union subset:

- `Nemotron-Cascade-2-30B-A3B-Q6`: `0.7717`
- `Qwen3.5-35B-A3B-IQ4`: `0.7717`

Solved counts:
- `Nemotron-Cascade-2-30B-A3B-Q6`: `71 / 92`
- `Qwen3.5-35B-A3B-IQ4`: `71 / 92`

Delta:
- `0` solved problems
- `0.0000` union pass@1

## Difficulty Breakdown

`Nemotron-Cascade-2-30B-A3B-Q6`:
- easy: `31 / 32 = 0.9688`
- medium: `34 / 39 = 0.8718`
- hard: `6 / 21 = 0.2857`

`Qwen3.5-35B-A3B-IQ4`:
- easy: `30 / 32 = 0.9375`
- medium: `33 / 39 = 0.8462`
- hard: `8 / 21 = 0.3810`

Delta:
- easy: `+0.0313`
- medium: `+0.0256`
- hard: `-0.0953`

Interpretation:
- Nemotron was slightly better on easy and medium.
- Qwen remained clearly better on hard.
- Those differences canceled out exactly on the overall 92-problem union.

## Per-Window Scores

`Nemotron-Cascade-2-30B-A3B-Q6`:
- `2024-01-01 .. 2024-02-29`: `0.8056`
- `2024-05-01 .. 2024-06-30`: `0.8409`
- `2025-04-01 .. 2025-05-31`: `0.4167`

`Qwen3.5-35B-A3B-IQ4`:
- `2024-01-01 .. 2024-02-29`: `0.8333`
- `2024-05-01 .. 2024-06-30`: `0.8182`
- `2025-04-01 .. 2025-05-31`: `0.4167`

Interpretation:
- Qwen was better in window 1.
- Nemotron was better in window 2.
- Window 3 was tied.

## Runtime

`Nemotron-Cascade-2-30B-A3B-Q6`:
- total runtime: `17148s`
- window 1 runtime: `7618s`
- window 2 runtime: `5668s`
- window 3 runtime: `3862s`

`Qwen3.5-35B-A3B-IQ4`:
- total runtime: `2988s`
- window 1 runtime: `944s`
- window 2 runtime: `989s`
- window 3 runtime: `1055s`

Runtime delta:
- Nemotron was slower by `14160s`
- Nemotron took about `5.74x` the Qwen wall-clock time

## Summary

On this 92-problem subset, `Nemotron-Cascade-2-30B-A3B-Q6` did not beat the incumbent `Qwen3.5-35B-A3B-IQ4`, but it did match it exactly on overall pass@1:

- `0.7717` vs `0.7717`
- `71 / 92` vs `71 / 92`

The shape of the tie matters:
- Nemotron was slightly better on easy and medium.
- Qwen was materially better on hard.
- Nemotron needed much longer wall-clock time to arrive at the tie.
