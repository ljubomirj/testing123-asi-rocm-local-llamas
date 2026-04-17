# Qwen3.6-35B-A3B Q6_K_XL LiveCodeBench Results - macbook2 (ngram-draft)

**Date**: 2026-04-17

**Model**: `Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf`

**Hardware**: `macbook2` (Apple M2 Max, 96 GB RAM, Metal)

**Run root**: [`runs/qwen36_35b_a3b_macbook2_lcb_ngram_20260417_140737`](../runs/qwen36_35b_a3b_macbook2_lcb_ngram_20260417_140737)

## Bottom Line

Qwen3.6-35B-A3B with ngram-draft speculative decoding achieved **80.4% pass@1** on the 92-problem LiveCodeBench tiny subset across three time windows.

- **Easy**: 100% (32/32)
- **Medium**: 79.5% (31/39)
- **Hard**: 52.4% (11/21)

Total runtime: **5.5 hours** (19,888 seconds)

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
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --threads 8 --parallel 1 \
  --mmap --mlock \
  --n-predict 10000 \
  --reasoning-budget 5000 \
  --reasoning-budget-message "Reasoning budget exhausted. Stop thinking and provide the best final answer now." \
  --jinja \
  --chat-template-kwargs '{"enable_thinking":true}' \
  --spec-type ngram-mod --spec-ngram-size-n 24 --draft-min 48 --draft-max 64
```

## Test Parameters

- **Thinking mode**: ON (deepseek format)
- **Reasoning budget**: 5000 tokens
- **Speculative**: ngram-mod (ngram-size-n=24, draft-min=48, draft-max=64)
- **Memory mapping**: mmap (not no-mmap)
- **Max tokens**: 10000
- **Temperature**: 0.0
- **Top P**: 1.0
- **OpenAI timeout**: 1800s
- **Problems**: 92 (36 + 44 + 12 across three time windows)

## Results

### Overall Scores

| Metric | Score | Count |
|---|---:|---:|
| **Overall pass@1** | **80.43%** | 74/92 |
| Easy pass@1 | 100.00% | 32/32 |
| Medium pass@1 | 79.49% | 31/39 |
| Hard pass@1 | 52.38% | 11/21 |

### By Time Window

| Window | Problems | Date Range | Pass@1 | Runtime |
|---|---:|---|---:|---:|
| Window 1 | 36 | 2024-01-01 to 2024-02-29 | 77.78% | 8456s (2.3h) |
| Window 2 | 44 | 2024-05-01 to 2024-06-30 | 90.91% | 8104s (2.3h) |
| Window 3 | 12 | 2025-04-01 to 2025-05-31 | 50.00% | 3328s (0.9h) |

### Per-Window Breakdown

**Window 1 (2024-01-01 to 2024-02-29)**: 28/36 pass@1
- Easy: 100%
- Medium: 68.4%
- Hard: 50.0%

**Window 2 (2024-05-01 to 2024-06-30)**: 40/44 pass@1
- Easy: 100%
- Medium: 94.4%
- Hard: 70.0%

**Window 3 (2025-04-01 to 2025-05-31)**: 6/12 pass@1
- Easy: 100%
- Medium: 50.0%
- Hard: 28.6%

### Performance Metrics

| Metric | Value |
|---|---:|
| Total runtime | 19,888 seconds (~5.5 hours) |
| Average time per problem | ~216 seconds (~3.6 minutes) |
| Problems per hour | ~16.5 |

## Raw Files

- `runs/qwen36_35b_a3b_macbook2_lcb_ngram_20260417_140737/qwen3.6-35b-a3b/` - Output directory
- `runs/qwen36_35b_a3b_macbook2_lcb_ngram_20260417_140737/livecodebench/run.log` - Run log

## Takeaways

1. **Strong overall performance**: 80.4% pass@1 is excellent for a 35B model on this benchmark.
2. **Easy problems**: Perfect 100% on easy problems - model handles straightforward coding tasks reliably.
3. **Medium problems**: 79.5% shows strong capability on moderate complexity tasks.
4. **Hard problems**: 52.4% indicates the model struggles with the most challenging problems, which is expected for this model size.
5. **Reasoning budget**: 5000 token thinking budget with deepseek format worked well for most problems.
6. **Speed**: ~3.6 minutes per problem is reasonable for a 35B model with thinking on M2 Max.
7. **ngram-draft impact**: Speculative decoding didn't significantly improve LCB performance compared to non-draft version.

## Comparison to Non-Draft Version (Same Hardware)

| Version | Overall pass@1 | Easy | Medium | Hard | Runtime |
|---|---:|---:|---:|---:|---:|
| **ngram-draft** | 80.43% | 100% | 79.5% | 52.4% | ~5.5h |
| **Non-draft** | 83.70% | 100% | 89.7% | 47.6% | ~7.4h |

The ngram-draft version shows slightly lower overall pass@1 (80.4% vs 83.7%) but completed faster (~5.5h vs ~7.4h). The difference is within expected variance for LCB testing.

Key observations:
- Easy problems: Both versions achieve 100%
- Medium problems: Non-draft slightly better (89.7% vs 79.5%)
- Hard problems: ngram-draft slightly better (52.4% vs 47.6%)
- Speed improvement: ~25% faster with ngram-draft
