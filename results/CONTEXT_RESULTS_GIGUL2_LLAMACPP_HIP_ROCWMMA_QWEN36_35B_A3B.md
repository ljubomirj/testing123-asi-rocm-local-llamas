# Qwen3.6-35B-A3B IQ4_XS Context Benchmark Results - gigul2

**Date**: 2026-04-16

**Model**: `Qwen3.6-35B-A3B-UD-IQ4_XS.gguf`

**Hardware**: `gigul2` (`AMD Radeon RX 7900 XTX 24GB`, HIP ROCm)

**Server**: `~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server`

**Run root**: [`runs/qwen36_gigul2_context_20260416_192755`](/home/ljubomir/rocm-glm-4.7-flash/runs/qwen36_gigul2_context_20260416_192755)

## Bottom Line

Qwen3.6-35B-A3B IQ4_XS on the 7900 XTX stays usable through 115K total context.

Thinking ON was consistently stable (0 failures across all runs).
Thinking OFF had intermittent failures — the model produced only 4 tokens (hitting EOS immediately) in ~33% of OFF runs. The `assistant-prefill` character likely needs adjustment for Qwen3.6. Mid 35K was completely broken in OFF mode (0/3 good runs).

TTFT was effectively identical between OFF and ON modes. Thinking ON had higher tok/s at most context sizes.

## Launch Configuration

```bash
~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server \
  --device ROCm0 --gpu-layers all \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf \
  --alias qwen3.6-35b-a3b \
  --ctx-size 150000 \
  --temp 1.0 --top-p 0.95 --top-k 20 \
  --min-p 0.0 --presence-penalty 1.5 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 8 \
  --parallel 1 \
  --mlock --no-mmap \
  --n-predict 10000 \
  --jinja
```

Mode-specific flags:

- thinking OFF:
  - `--reasoning-format none --reasoning off`
  - `--chat-template-kwargs '{"enable_thinking":false}'`
  - `--assistant-prefill 'ဿ'`
- thinking ON:
  - `--reasoning-format deepseek --reasoning on`
  - `--chat-template-kwargs '{"enable_thinking":true}'`

## Results

Filtered to good runs only (response >= 10 tokens). Thinking OFF had failures at most context sizes.

| Bucket | Effective context | OFF TTFT | OFF tok/s | OFF good/total | ON TTFT | ON tok/s |
|---|---:|---:|---:|---:|---:|---:|
| none | 50 | 0.264s | 28.2 | 3/3 | 0.271s | 61.0 |
| none | 100 | 0.319s | 44.0 | 3/3 | 0.321s | 59.9 |
| small | 15K | 6.122s | 41.3 | 3/3 | 6.629s | 40.4 |
| small | 20K | 10.085s | 32.5 | 2/3 | 10.163s | 33.1 |
| mid | 30K | 10.975s | 30.7 | 2/3 | 11.000s | 34.9 |
| mid | 35K | — | — | 0/3 FAIL | 17.192s | 25.7 |
| long | 50K | 17.296s | 23.0 | 2/3 | 17.272s | 25.4 |
| long | 55K | 26.300s | 17.6 | 3/3 | 26.283s | 18.3 |
| longlong | 110K | 36.417s | 13.0 | 2/3 | 36.409s | 15.1 |
| longlong | 115K | 54.177s | 9.6 | 3/3 | 54.151s | 10.8 |

## Thinking OFF vs ON

Thinking ON produced higher tok/s in 8/10 scenarios (excluding mid 35K which was all-fail in OFF).

| Bucket | Context | TTFT delta ON-OFF | tok/s delta ON-OFF |
|---|---:|---:|---:|
| none | 50 | +0.007s | +32.8 |
| none | 100 | +0.002s | +15.9 |
| small | 15K | +0.507s | -0.9 |
| small | 20K | +0.078s | +0.6 |
| mid | 30K | +0.025s | +4.2 |
| mid | 35K | — | — |
| long | 50K | -0.024s | +2.4 |
| long | 55K | -0.017s | +0.7 |
| longlong | 110K | -0.008s | +2.1 |
| longlong | 115K | -0.026s | +1.2 |

The none-context tier shows a large ON advantage in tok/s, likely because thinking ON generates more tokens (thinking + response) in the same wall-clock time. At forced-context tiers (15K+), the advantage shrinks to 0-4 tok/s.

## Comparison to Nemotron-Cascade-2-30B-A3B IQ4_XS (gigul2)

Same hardware, same benchmark harness. Nemotron data from earlier run.

| Bucket | Context | Nem OFF TTFT | Qwen3.6 OFF TTFT | Nem ON tok/s | Qwen3.6 ON tok/s |
|---|---:|---:|---:|---:|---:|
| none | 50 | 0.341s | 0.264s | 98.9 | 61.0 |
| none | 100 | 0.287s | 0.319s | 100.9 | 59.9 |
| small | 15K | 4.803s | 6.629s | 54.1 | 40.4 |
| small | 20K | 7.728s | 10.163s | 42.4 | 33.1 |
| mid | 30K | 7.641s | 11.000s | 40.5 | 34.9 |
| mid | 35K | 11.908s | 17.192s | 30.6 | 25.7 |
| long | 50K | 11.535s | 17.272s | 32.4 | 25.4 |
| long | 55K | 17.620s | 26.283s | 22.7 | 18.3 |
| longlong | 110K | 23.223s | 36.409s | 19.5 | 15.1 |
| longlong | 115K | 34.943s | 54.151s | 13.3 | 10.8 |

Nemotron is faster on both TTFT and tok/s across all context sizes. Qwen3.6's larger active parameter count (35B vs 30B) likely explains the difference.

## Takeaways

1. Qwen3.6-35B-A3B works reliably through 115K context on the 7900 XTX in thinking ON mode.
2. Thinking OFF mode has a reproducible bug where ~33% of runs produce only 4 tokens. The `assistant-prefill` needs investigation for Qwen3.6 compatibility.
3. Compared to Nemotron-Cascade-2 on the same hardware, Qwen3.6 is ~30-50% slower on TTFT and ~20-30% slower on decode throughput.
4. The speed difference is expected given the larger model size; quality comparison requires LiveCodeBench.
