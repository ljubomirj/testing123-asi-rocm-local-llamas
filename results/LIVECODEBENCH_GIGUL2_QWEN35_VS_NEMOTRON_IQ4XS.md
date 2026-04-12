# LiveCodeBench: Qwen35 vs Nemotron IQ4_XS on gigul2

**Date**: 2026-03-28

## Compared Runs

- Qwen incumbent:
  - [`benchmark_results_livecodebench_qwen35b_recheck_20260315_171139`](/home/ljubomir/rocm-glm-4.7-flash/benchmark_results_livecodebench_qwen35b_recheck_20260315_171139)
- Nemotron thinking OFF:
  - [`runs/nemotron_gigul2_suite_20260327_221821/livecodebench_off`](/home/ljubomir/rocm-glm-4.7-flash/runs/nemotron_gigul2_suite_20260327_221821/livecodebench_off)
- Nemotron thinking ON, reasoning budget `5000`, total cap `10000`:
  - [`runs/nemotron_gigul2_suite_20260327_221821/livecodebench_on_budget5k_total10k`](/home/ljubomir/rocm-glm-4.7-flash/runs/nemotron_gigul2_suite_20260327_221821/livecodebench_on_budget5k_total10k)

## Bottom Line

On the same `gigul2` 92-problem union subset, `Nemotron-Cascade-2-30B-A3B-IQ4_XS` with bounded thinking beat the prior local `Qwen3.5-35B-A3B-IQ4` incumbent.

The three practical local operating points were:

- Qwen incumbent, thinking OFF: `0.7717` in `2988s`
- Nemotron thinking OFF: `0.5326` in `1907s`
- Nemotron thinking ON, budget `5000 / 10000`: `0.8261` in `3776s`

So:

- thinking OFF is faster but much worse than Qwen
- budgeted thinking ON beats Qwen by accuracy while staying within roughly `1.26x` the Qwen wall-clock time

## Score Summary

| Model / mode | Thinking | Total cap | Thinking budget | Overall | Easy | Medium | Hard | Solved | Runtime |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Qwen3.5-35B-A3B-IQ4 | OFF | 10000 | n/a | 0.7717 | 0.9375 | 0.8462 | 0.3810 | 71 / 92 | 2988s |
| Nemotron-Cascade-2-30B-A3B-IQ4_XS | OFF | 10000 | n/a | 0.5326 | 0.8750 | 0.4872 | 0.0952 | 49 / 92 | 1907s |
| Nemotron-Cascade-2-30B-A3B-IQ4_XS | ON | 10000 | 5000 | 0.8261 | 1.0000 | 0.8462 | 0.5238 | 76 / 92 | 3776s |

## Readout

- Budgeted Nemotron ON beat Qwen by `+5` solved problems on the union subset: `76 / 92` vs `71 / 92`.
- The easy bucket improved from `30 / 32` to `32 / 32`.
- The medium bucket was tied at `33 / 39`.
- The hard bucket improved from `8 / 21` to `11 / 21`.
- Nemotron OFF was not competitive. It dropped to `49 / 92`, with hard collapsing to `2 / 21`.

This means the gain over Qwen came mostly from:

- perfecting the easy bucket
- lifting hard from `0.3810` to `0.5238`

## Per-Window Scores

| Window | Qwen OFF | Nemotron OFF | Nemotron ON budget 5k |
|---|---:|---:|---:|
| `2024-01-01 .. 2024-02-29` | 0.8333 | 0.5278 | 0.7778 |
| `2024-05-01 .. 2024-06-30` | 0.8182 | 0.6136 | 0.9318 |
| `2025-04-01 .. 2025-05-31` | 0.4167 | 0.2500 | 0.5833 |

Interpretation:

- Qwen stayed better in window 1.
- Budgeted Nemotron was clearly better in windows 2 and 3.
- Nemotron OFF lost all three windows.

## Runtime Readout

| Model / mode | Window 1 | Window 2 | Window 3 | Total |
|---|---:|---:|---:|---:|
| Qwen3.5-35B-A3B-IQ4 OFF | 944s | 989s | 1055s | 2988s |
| Nemotron OFF | 1059s | 646s | 202s | 1907s |
| Nemotron ON budget 5k | 1447s | 1561s | 768s | 3776s |

Key runtime deltas:

- Budgeted Nemotron vs Qwen: `+788s`, about `1.26x` Qwen runtime
- Budgeted Nemotron vs Nemotron OFF: `+1869s`, but with `+27` solved problems
- Nemotron OFF vs Qwen: `-1081s`, but with `-22` solved problems

## Source Score Files

Qwen:

- union: [`scores_union_three_windows.txt`](/home/ljubomir/rocm-glm-4.7-flash/benchmark_results_livecodebench_qwen35b_recheck_20260315_171139/Qwen3.5-35B-A3B-IQ4_subset/Qwen3.5-35B-A3B-IQ4/scores_union_three_windows.txt)
- run log: [`Qwen3.5-35B-A3B-IQ4.run.log`](/home/ljubomir/rocm-glm-4.7-flash/benchmark_results_livecodebench_qwen35b_recheck_20260315_171139/Qwen3.5-35B-A3B-IQ4.run.log)

Nemotron OFF:

- union: [`scores_union_three_windows.txt`](/home/ljubomir/rocm-glm-4.7-flash/runs/nemotron_gigul2_suite_20260327_221821/livecodebench_off/Nemotron-Cascade-2-30B-A3B-IQ4_XS/scores_union_three_windows.txt)
- run log: [`Nemotron-Cascade-2-30B-A3B-IQ4_XS.run.log`](/home/ljubomir/rocm-glm-4.7-flash/runs/nemotron_gigul2_suite_20260327_221821/livecodebench_off/Nemotron-Cascade-2-30B-A3B-IQ4_XS.run.log)

Nemotron ON budget `5000 / 10000`:

- union: [`scores_union_three_windows.txt`](/home/ljubomir/rocm-glm-4.7-flash/runs/nemotron_gigul2_suite_20260327_221821/livecodebench_on_budget5k_total10k/Nemotron-Cascade-2-30B-A3B-IQ4_XS/scores_union_three_windows.txt)
- run log: [`Nemotron-Cascade-2-30B-A3B-IQ4_XS.run.log`](/home/ljubomir/rocm-glm-4.7-flash/runs/nemotron_gigul2_suite_20260327_221821/livecodebench_on_budget5k_total10k/Nemotron-Cascade-2-30B-A3B-IQ4_XS.run.log)

## Caveat

This is a same-hardware comparison on the same 92-problem subset, but it is not the same reasoning mode:

- Qwen incumbent is the local deterministic non-thinking run
- Nemotron winner is the local budgeted-thinking run

That is the point of the comparison: on gigul2, the winning Nemotron operating point is bounded thinking, not thinking OFF.
