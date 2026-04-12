# Thinking A/B Pilot Report

Run root: `/home/ljubomir/rocm-glm-4.7-flash/benchmark_results_livecodebench_thinking_ab_20260311_170646`

Scope:
- 20 pilot question IDs
- IDs selected from prior-empty GLM thinking-on cases
- max_tokens fixed at 5000
- stages:
  - `A_reasoning`: `deepseek`, `none`, `deepseek-legacy`
  - `C_sampling`: `baseline`, `tuned`

## Headline

Thinking mode performed poorly on this pilot across all tested models.

- Best observed result: `0.1000` pass@1
- Empty outputs were eliminated (`empty_output_rate = 0.0000` everywhere)
- Main remaining failure mode was missing extractable code (`empty_code_rate` often `0.80` to `1.00`)

## Best Result Per Model

| Model | Best case | Pass@1 | Empty code rate | Notes |
| --- | --- | ---: | ---: | --- |
| Qwen3.5-35B-A3B-IQ4 | `C_sampling / tuned` | `0.0500` | `0.9500` | Slightly better than all-zero alternatives |
| Qwen3.5-27B-Q4 | tie across all 5 tested cases | `0.1000` | `0.8500` | Reasoning format and tuned sampling made no difference |
| Qwen3.5-9B-Q8 | tie at `0.0000` | `0.0000` | best `0.9000` | Tuned sampling reduced empty-code rate slightly, but no passes |
| GLM-4.7-Flash-Q4 | `C_sampling / tuned` | `0.1000` | `0.8000` | Best GLM case used `reasoning_format=none` |

## Full Results

### Qwen3.5-35B-A3B-IQ4

| Stage | Case | Reasoning format | Temp | Top-p | Top-k | Min-p | Pass@1 | Empty output | Empty code | Runtime (s) |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A_reasoning | deepseek | deepseek | 1.0 | 0.95 | - | - | `0.0000` | `0.0000` | `1.0000` | 1850 |
| A_reasoning | none | none | 1.0 | 0.95 | - | - | `0.0000` | `0.0000` | `1.0000` | 1849 |
| A_reasoning | deepseek-legacy | deepseek-legacy | 1.0 | 0.95 | - | - | `0.0000` | `0.0000` | `1.0000` | 1864 |
| C_sampling | baseline | deepseek | 1.0 | 0.95 | - | - | `0.0000` | `0.0000` | `1.0000` | 1846 |
| C_sampling | tuned | deepseek | 0.6 | 0.95 | 20 | 0 | `0.0500` | `0.0000` | `0.9500` | 1525 |

Selected best reasoning format: `deepseek`

### Qwen3.5-27B-Q4

| Stage | Case | Reasoning format | Temp | Top-p | Top-k | Min-p | Pass@1 | Empty output | Empty code | Runtime (s) |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A_reasoning | deepseek | deepseek | 1.0 | 0.95 | - | - | `0.1000` | `0.0000` | `0.8500` | 4066 |
| A_reasoning | none | none | 1.0 | 0.95 | - | - | `0.1000` | `0.0000` | `0.8500` | 4063 |
| A_reasoning | deepseek-legacy | deepseek-legacy | 1.0 | 0.95 | - | - | `0.1000` | `0.0000` | `0.8500` | 4057 |
| C_sampling | baseline | deepseek | 1.0 | 0.95 | - | - | `0.1000` | `0.0000` | `0.8500` | 4074 |
| C_sampling | tuned | deepseek | 0.6 | 0.95 | 20 | 0 | `0.1000` | `0.0000` | `0.8500` | 3776 |

Selected best reasoning format: `deepseek`

### Qwen3.5-9B-Q8

| Stage | Case | Reasoning format | Temp | Top-p | Top-k | Min-p | Pass@1 | Empty output | Empty code | Runtime (s) |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A_reasoning | deepseek | deepseek | 1.0 | 0.95 | - | - | `0.0000` | `0.0000` | `1.0000` | 2437 |
| A_reasoning | none | none | 1.0 | 0.95 | - | - | `0.0000` | `0.0000` | `1.0000` | 2435 |
| A_reasoning | deepseek-legacy | deepseek-legacy | 1.0 | 0.95 | - | - | `0.0000` | `0.0000` | `1.0000` | 2436 |
| C_sampling | baseline | deepseek | 1.0 | 0.95 | - | - | `0.0000` | `0.0000` | `1.0000` | 2435 |
| C_sampling | tuned | deepseek | 0.6 | 0.95 | 20 | 0 | `0.0000` | `0.0000` | `0.9000` | 2122 |

Selected best reasoning format: `deepseek`

### GLM-4.7-Flash-Q4

| Stage | Case | Reasoning format | Temp | Top-p | Top-k | Min-p | Pass@1 | Empty output | Empty code | Runtime (s) |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A_reasoning | deepseek | deepseek | 1.0 | 0.95 | - | - | `0.0500` | `0.0000` | `0.9000` | 1742 |
| A_reasoning | none | none | 1.0 | 0.95 | - | - | `0.0500` | `0.0000` | `0.8500` | 1753 |
| A_reasoning | deepseek-legacy | deepseek-legacy | 1.0 | 0.95 | - | - | `0.0500` | `0.0000` | `0.8500` | 1756 |
| C_sampling | baseline | none | 1.0 | 0.95 | - | - | `0.0500` | `0.0000` | `0.8500` | 1762 |
| C_sampling | tuned | none | 0.7 | 1.0 | - | - | `0.1000` | `0.0000` | `0.8000` | 1642 |

Selected best reasoning format: `none`

## Conclusion

For this 20-ID thinking-on code-generation pilot:

- no model showed strong benefit from thinking mode
- `reasoning_format` changes did not materially help Qwen
- Qwen tuned sampling helped only the 35B model slightly
- GLM responded best to `reasoning_format=none` plus tuned sampling, but still only reached `0.1000` pass@1
- the pathology shifted from empty outputs to non-code or non-extractable outputs

Raw source of record: `summary.csv`
