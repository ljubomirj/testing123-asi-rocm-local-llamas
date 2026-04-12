# Nemotron-Cascade-2-30B-A3B IQ4_XS Context Benchmark Results - gigul2

**Date**: 2026-03-27

**Model**: `Nemotron-Cascade-2-30B-A3B-IQ4_XS.gguf`

**Hardware**: `gigul2` (`AMD Radeon RX 7900 XTX 24GB`, HIP ROCm)

**Server**: `~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server`

**Run root**: [`runs/nemotron_gigul2_suite_20260327_221821`](/home/ljubomir/rocm-glm-4.7-flash/runs/nemotron_gigul2_suite_20260327_221821)

**Raw context outputs**: [`context/`](/home/ljubomir/rocm-glm-4.7-flash/runs/nemotron_gigul2_suite_20260327_221821/context)

## Bottom Line

The gigul2 ROCm run completed the full `none`, `small`, `mid`, `long`, and `longlong` context suite in both thinking modes.

At the 7900 XTX `IQ4_XS` setting, Nemotron stayed usable all the way to `115K` total context:

- thinking OFF: `34.697s` TTFT and `11.5 tok/s` at `115K`
- thinking ON: `34.943s` TTFT and `13.3 tok/s` at `115K`

Thinking ON was consistently a little faster on decode throughput, while TTFT stayed effectively the same across the full forced-context matrix.

## Launch Configuration

The gigul2 context suite used the same non-model-specific llama.cpp settings as the recent macbook2 wrapper runs:

```bash
~/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server \
  --device ROCm0 --gpu-layers all \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Nemotron-Cascade-2-30B-A3B-IQ4_XS.gguf \
  --alias nemotron-cascade-2-30b-a3b \
  --ctx-size 150000 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 1 \
  --mlock --no-mmap \
  --n-predict 10000 \
  --jinja
```

Mode-specific flags:

- thinking OFF:
  - `--reasoning-format none --reasoning off`
  - `--chat-template-kwargs '{"enable_thinking":false}'`
  - `--assistant-prefill '<think></think>'`
- thinking ON:
  - `--reasoning-format deepseek --reasoning on`
  - `--chat-template-kwargs '{"enable_thinking":true}'`

## Results

| Scenario | Total context | OFF TTFT | OFF tok/s | ON TTFT | ON tok/s |
|---|---:|---:|---:|---:|---:|
| None | 50 | 0.341s | 89.4 | 0.393s | 98.9 |
| None | 100 | 0.287s | 93.5 | 0.314s | 100.9 |
| Small | 15K | 4.754s | 43.5 | 4.803s | 54.1 |
| Small | 20K | 7.700s | 35.1 | 7.728s | 42.4 |
| Mid | 30K | 7.618s | 35.4 | 7.641s | 40.5 |
| Mid | 35K | 11.862s | 25.4 | 11.908s | 30.6 |
| Long | 50K | 11.519s | 27.0 | 11.535s | 32.4 |
| Long | 55K | 17.588s | 20.3 | 17.620s | 22.7 |
| Longlong | 110K | 23.206s | 15.5 | 23.223s | 19.5 |
| Longlong | 115K | 34.697s | 11.5 | 34.943s | 13.3 |

## Thinking OFF vs ON

Thinking ON improved decode throughput in all `10/10` measured scenarios.

| Scenario | TTFT delta ON-OFF | tok/s delta ON-OFF |
|---|---:|---:|
| None 50 | +0.052s | +9.5 |
| None 100 | +0.027s | +7.4 |
| Small 15K | +0.049s | +10.6 |
| Small 20K | +0.028s | +7.3 |
| Mid 30K | +0.023s | +5.1 |
| Mid 35K | +0.046s | +5.2 |
| Long 50K | +0.016s | +5.4 |
| Long 55K | +0.032s | +2.4 |
| Longlong 110K | +0.017s | +4.0 |
| Longlong 115K | +0.246s | +1.8 |

The cost of enabling thinking on this setup was tiny in TTFT terms, while generation throughput improved materially.

## Comparison to Prior Qwen3.5-35B-A3B gigul2 Baseline

The correct same-hardware baseline is the earlier gigul2 run in [`benchmark_results_qwen35-35b-a3b-q4km_2026-02-27/`](/home/ljubomir/rocm-glm-4.7-flash/benchmark_results_qwen35-35b-a3b-q4km_2026-02-27), using `Qwen3.5-35B-A3B-UD-Q4_K_M` on the same `7900 XTX`.

This is a much better comparison than the macbook2 rerun because:

- same machine: `gigul2`
- same backend family: llama.cpp HIP ROCm
- same forced-context ladder: `15K`, `20K`, `30K`, `35K`, `50K`, `55K`, `110K`, `115K`

Remaining caveats:

- quant is still different: `Qwen Q4_K_M` vs `Nemotron IQ4_XS`
- the old Qwen none-context tier used `max_tokens=512`, while the current Nemotron none-context tier used `max_tokens=200`

So the strongest apples-to-apples comparison is the forced-context range from `15K` through `115K`.

### gigul2 Qwen Baseline Used

| Scenario | Qwen TTFT | Qwen tok/s |
|---|---:|---:|
| None 50 | 0.149s | 71.5 |
| None 100 | 0.188s | 80.2 |
| Small 15K | 6.889s | 43.2 |
| Small 20K | 11.343s | 31.5 |
| Mid 30K | 11.725s | 30.9 |
| Mid 35K | 18.320s | 24.6 |
| Long 50K | 18.037s | 25.6 |
| Long 55K | 27.444s | 17.3 |
| Longlong 110K | 37.200s | 12.5 |
| Longlong 115K | 55.337s | 10.1 |

### Nemotron vs Qwen on gigul2

| Scenario | Qwen TTFT | Nemotron OFF TTFT | Nemotron ON TTFT | Qwen tok/s | Nemotron OFF tok/s | Nemotron ON tok/s |
|---|---:|---:|---:|---:|---:|---:|
| None 50 | 0.149s | 0.341s | 0.393s | 71.5 | 89.4 | 98.9 |
| None 100 | 0.188s | 0.287s | 0.314s | 80.2 | 93.5 | 100.9 |
| Small 15K | 6.889s | 4.754s | 4.803s | 43.2 | 43.5 | 54.1 |
| Small 20K | 11.343s | 7.700s | 7.728s | 31.5 | 35.1 | 42.4 |
| Mid 30K | 11.725s | 7.618s | 7.641s | 30.9 | 35.4 | 40.5 |
| Mid 35K | 18.320s | 11.862s | 11.908s | 24.6 | 25.4 | 30.6 |
| Long 50K | 18.037s | 11.519s | 11.535s | 25.6 | 27.0 | 32.4 |
| Long 55K | 27.444s | 17.588s | 17.620s | 17.3 | 20.3 | 22.7 |
| Longlong 110K | 37.200s | 23.206s | 23.223s | 12.5 | 15.5 | 19.5 |
| Longlong 115K | 55.337s | 34.697s | 34.943s | 10.1 | 11.5 | 13.3 |

### Readout

- On the clean forced-context range `15K` through `115K`, Nemotron thinking OFF beat the prior gigul2 Qwen run on TTFT in `8/8` scenarios and on throughput in `8/8`.
- On that same forced-context range, Nemotron thinking ON also beat the prior gigul2 Qwen run on TTFT in `8/8` scenarios and on throughput in `8/8`.
- The none-context tier is mixed:
  - Qwen still had lower TTFT at `50` and `100` total tokens
  - Nemotron still had higher decode throughput at `50` and `100`
- The biggest absolute TTFT win over the gigul2 Qwen baseline was at `Longlong 115K`:
  - OFF: `34.697s` vs `55.337s` (`-20.639s`)
  - ON: `34.943s` vs `55.337s` (`-20.394s`)
- The biggest throughput win over the gigul2 Qwen baseline was at `Longlong 110K` for thinking ON:
  - `19.5 tok/s` vs `12.5 tok/s` (`+7.0 tok/s`)

## Takeaways

1. The 7900 XTX ROCm llama.cpp build is strong enough to carry this Nemotron IQ4_XS model cleanly through `115K` total context with acceptable TTFT.
2. On speed alone, this gigul2 Nemotron profile is well ahead of the prior gigul2 `Qwen3.5-35B-A3B-UD-Q4_K_M` baseline across the whole forced-context matrix.
3. That does not by itself prove better model quality. The benchmark here is purely latency and decode throughput.
