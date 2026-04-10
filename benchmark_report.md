# LiveCodeBench Subset Report (Qwen3.5, llama.cpp, 7900XTX)

Date run: 2026-03-08  
Subset windows:
- 2024-01-01 .. 2024-02-29 (36)
- 2024-05-01 .. 2024-06-30 (44)
- 2025-04-01 .. 2025-05-31 (12)

Total subset size: 92 problems

## Jan 2024 - Feb 2024 (36 problems)

| Model | Easy | Medium | Hard | Overall |
|---|---:|---:|---:|---:|
| 35B | 100.0% | 78.9% | 0.0% | 77.8% |
| 27B | 92.3% | 42.1% | 25.0% | 58.3% |
| 9B | 100.0% | 42.1% | 0.0% | 58.3% |

## May 2024 - Jun 2024 (44 problems)

| Model | Easy | Medium | Hard | Overall |
|---|---:|---:|---:|---:|
| 35B | 100.0% | 72.2% | 50.0% | 77.3% |
| 27B | 100.0% | 66.7% | 20.0% | 68.2% |
| 9B | 87.5% | 61.1% | 0.0% | 56.8% |

## Apr 2025 - May 2025 (12 problems)

| Model | Easy | Medium | Hard | Overall |
|---|---:|---:|---:|---:|
| 35B | 100.0% | 50.0% | 14.3% | 41.7% |
| 27B | 100.0% | 0.0% | 14.3% | 33.3% |
| 9B | 100.0% | 50.0% | 0.0% | 33.3% |

## Average (All of the above)

| Model | Easy | Medium | Hard | Overall |
|---|---:|---:|---:|---:|
| 35B | 100.0% | 74.4% | 28.6% | 72.8% |
| 27B | 96.9% | 51.3% | 19.0% | 59.8% |
| 9B | 93.8% | 51.3% | 0.0% | 54.3% |

## Speed (same 92-problem subset)

| Model | Total runtime | Problems/min |
|---|---:|---:|
| 35B | 2072 s (34.5 min) | 2.66 |
| 27B | 4482 s (74.7 min) | 1.23 |
| 9B | 2995 s (49.9 min) | 1.84 |

## Repro notes

- Server: `llama.cpp` (`llama-server`) on AMD 7900XTX.
- Models:
  - `Qwen3.5-35B-A3B-UD-IQ4_XS.gguf`
  - `Qwen3.5-27B-UD-Q4_K_XL.gguf`
  - `Qwen3.5-9B-UD-Q8_K_XL.gguf`
- Reasoning disabled on server (`--reasoning-budget 0`, `--reasoning-format none`) and ChatML thinking hint disabled.
- Decoding used for benchmark: `temperature=0.0`, `top_p=1.0`.
- `max_tokens=4000` was used for stable termination in this llama.cpp + Qwen setup.
  - `100000` caused frequent very long/non-terminating generations in this benchmark path.
- After run, a rescore pass was done to handle truncated fenced-code outputs robustly.

## Rescoring note (important)

- Initial scores were produced by the normal LiveCodeBench evaluation path during generation (`lcb_runner.runner.main --evaluate`), then aggregated by `compute_scores`.
- In this setup, some responses were cut with an opening markdown code fence but without a closing fence.
- The default extractor expected two fences and returned empty code when the closing fence was missing, which created false-zero Pass@1 in some windows.
- Rescoring did **not** regenerate model outputs.
  - It reused saved generations from `LiveCodeBench/output/<model>/Scenario.codegeneration_1_0.0.json`.
  - It re-extracted code with a fallback: if only one fence exists, extract from that fence to end.
  - It re-ran evaluation on the same 36/44/12 subset.
- Speed metrics are unchanged; only accuracy metrics were corrected by rescoring.

## Commands used

```bash
# 1) Run full 3-model matrix
MAX_TOKENS=4000 ./scripts/livecodebench_run_matrix.sh

# 2) Rescore outputs for final tables
cd LiveCodeBench
source .venv-lite/bin/activate
PYTHONPATH=. python ../scripts/livecodebench_rescore_matrix.py
```

## Artifacts

- Raw matrix summary:
  - `/home/ljubomir/rocm-glm-4.7-flash/benchmark_results_livecodebench_matrix_20260308_140216/summary.csv`
- Rescored metrics:
  - `/home/ljubomir/rocm-glm-4.7-flash/benchmark_results_livecodebench_rescored.json`
