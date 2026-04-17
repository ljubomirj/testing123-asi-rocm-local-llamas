# Qwen3.6-35B-A3B Q6_K_XL LiveCodeBench Results - macbook2

**Date**: 2026-04-17

**Model**: `Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf`

**Hardware**: `macbook2` (Apple M2 Max, 96 GB RAM, Metal)

**Run root**: [`runs/qwen36_35b_a3b_macbook2_lcb_20260417_041857`](../runs/qwen36_35b_a3b_macbook2_lcb_20260417_041857)

## Bottom Line

Qwen3.6-35B-A3B achieved **83.7% pass@1** on the 92-problem LiveCodeBench tiny subset across three time windows.

- **Easy**: 100% (32/32)
- **Medium**: 89.7% (35/39)
- **Hard**: 47.6% (10/21)

Total runtime: **7.4 hours** (26,693 seconds)

## Server Configuration

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --model ~/llama.cpp/models/Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf \
  --alias qwen3.6-35b-a3b \
  --host 0.0.0.0 --port 8081 \
  --gpu-layers all \
  --ctx-size 150000 \
  --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0.0 \
  --repeat-penalty 1.0 --presence-penalty 1.5 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 --kv-unified \
  --threads 8 --batch-size 2048 --ubatch-size 512 \
  --parallel 1 --no-mmap \
  --n-predict 10000 \
  --reasoning on --reasoning-format deepseek \
  --reasoning-budget 5000 \
  --reasoning-budget-message "Thinking budget exhausted. Stop thinking and provide the best final answer now." \
  --jinja \
  --chat-template-kwargs '{"enable_thinking":true}'
```

## Test Parameters

- **Thinking mode**: ON (deepseek format)
- **Reasoning budget**: 5000 tokens
- **Max tokens**: 10000
- **Temperature**: 0.0
- **Top P**: 1.0
- **OpenAI timeout**: 1800s
- **Problems**: 92 (36 + 44 + 12 across three time windows)

## Results

### Overall Scores

| Metric | Score | Count |
|---|---:|---:|
| **Overall pass@1** | **83.70%** | 77/92 |
| Easy pass@1 | 100.00% | 32/32 |
| Medium pass@1 | 89.74% | 35/39 |
| Hard pass@1 | 47.62% | 10/21 |

### By Time Window

| Window | Problems | Date Range |
|---|---:|---|
| Window 1 | 36 | 2024-01-01 to 2024-02-29 |
| Window 2 | 44 | 2024-05-01 to 2024-06-30 |
| Window 3 | 12 | 2025-04-01 to 2025-05-31 |

### Performance Metrics

| Metric | Value |
|---|---:|
| Total runtime | 26,693 seconds (~7.4 hours) |
| Average time per problem | ~290 seconds (~4.8 minutes) |
| Problems per hour | ~12.3 |

## Raw Files

- `runs/qwen36_35b_a3b_macbook2_lcb_20260417_041857/qwen3.6-35b-a3b/` - Output directory
- `runs/qwen36_35b_a3b_macbook2_lcb_20260417_041857/livecodebench/run.log` - Run log

## Takeaways

1. **Strong overall performance**: 83.7% pass@1 is excellent for a 35B model on this benchmark.
2. **Easy problems**: Perfect 100% on easy problems - model handles straightforward coding tasks reliably.
3. **Medium problems**: 89.7% shows strong capability on moderate complexity tasks.
4. **Hard problems**: 47.6% indicates the model struggles with the most challenging problems, which is expected for this model size.
5. **Reasoning budget**: 5000 token thinking budget with deepseek format worked well for most problems.
6. **Speed**: ~5 minutes per problem is reasonable for a 35B model with thinking on M2 Max.

## Comparison to Other Models (Same Hardware)

| Model | Overall pass@1 | Easy | Medium | Hard | Runtime |
|---|---:|---:|---:|---:|---:|
| Qwen3.6-35B-A3B Q6_K_XL | 83.70% | 100% | 89.7% | 47.6% | ~7.4h |
| MiniMax-M2.7 IQ2_XXS | Not tested | - | - | - | Too slow |

Qwen3.6-35B-A3B provides a good balance of speed and quality for LiveCodeBench on the M2 Max.
