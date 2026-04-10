# Qwen3.5-35B-A3B vs Nemotron-Cascade-2-30B-A3B on macbook2

**Date**: 2026-03-27

**Compared runs**:
- Qwen rerun: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_162504`
- Nemotron thinking OFF: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_175243`
- Nemotron thinking ON: `/Users/ljubomir/rocm-glm-4.7-flash/runs/20260326_181420`

## Bottom Line

On the refreshed macbook2 llama.cpp setup, `Nemotron-Cascade-2-30B-A3B.Q6_K` with thinking ON was not just competitive with the current `Qwen3.5-35B-A3B-UD-Q8_K_XL` rerun. It was faster on decode throughput in every measured case, and faster on TTFT for every forced-context band from `20K` through `115K` total context.

The only places where Qwen stayed competitive on latency were:
- `None (100 tok)`, where Qwen TTFT was lower (`0.45s` vs `0.50s`)
- `Small (15K)`, where TTFT was effectively tied (`11.96s` vs `11.98s`)

## Launch Scripts

Good macbook2 context results came from these wrapper scripts:
- Qwen rerun: [run_llama_qwen_wrapper_macbook2.sh](/Users/ljubomir/llama.cpp/run_llama_qwen_wrapper_macbook2.sh)
- Nemotron thinking OFF: [run_llama_nemotron_cascade_2_wrapper_macbook2.sh](/Users/ljubomir/llama.cpp/run_llama_nemotron_cascade_2_wrapper_macbook2.sh)
- Nemotron thinking ON: [run_llama_nemotron_cascade_2_thinking_wrapper_macbook2.sh](/Users/ljubomir/llama.cpp/run_llama_nemotron_cascade_2_thinking_wrapper_macbook2.sh)

## Exact llama-server Parameters

### Qwen rerun

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Qwen3.5-35B-A3B-UD-Q8_K_XL.gguf \
  --alias qwen3.5-35b-a3b \
  --ctx-size 262144 \
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
  --chat-template-kwargs '{"enable_thinking":false}' \
  --chat-template-file ~/llama.cpp/qwen3.5_chat_template.jinja
```

### Nemotron thinking OFF

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Nemotron-Cascade-2-30B-A3B.Q6_K.gguf \
  --alias nemotron-cascade-2-30b-a3b \
  --ctx-size 262144 \
  --temp 1.0 --top-p 0.95 --top-k 0 --min-p 0.0 \
  --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 1 \
  --mlock --no-mmap \
  --reasoning-format none --reasoning off \
  --n-predict 10000 \
  --jinja
```

### Nemotron thinking ON

```bash
~/llama.cpp/build-macbook2-metal/bin/llama-server \
  --host 127.0.0.1 --port 8081 \
  --model ~/llama.cpp/models/Nemotron-Cascade-2-30B-A3B.Q6_K.gguf \
  --alias nemotron-cascade-2-30b-a3b \
  --ctx-size 262144 \
  --temp 1.0 --top-p 0.95 --top-k 0 --min-p 0.0 \
  --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --kv-unified --cache-prompt \
  --cache-ram 16384 --cache-reuse 512 \
  --batch-size 2048 --ubatch-size 512 \
  --threads-batch 10 --threads 10 \
  --parallel 1 \
  --mlock --no-mmap \
  --reasoning-format deepseek --reasoning on \
  --n-predict 10000 \
  --jinja
```

## Results

| Scenario | Qwen TTFT | Nemotron OFF TTFT | Nemotron ON TTFT | Qwen tok/s | Nemotron OFF tok/s | Nemotron ON tok/s |
|---|---:|---:|---:|---:|---:|---:|
| None 50 | 0.356s | 0.267s | 0.318s | 39.0 | 49.7 | 57.7 |
| None 100 | 0.450s | 0.493s | 0.495s | 35.4 | 43.1 | 52.4 |
| Small 15K | 11.960s | 13.291s | 11.980s | 20.8 | 18.2 | 23.3 |
| Small 20K | 18.810s | 20.061s | 18.556s | 16.6 | 14.7 | 16.9 |
| Mid 30K | 14.740s | 15.021s | 14.045s | 17.4 | 16.1 | 21.4 |
| Mid 35K | 21.700s | 22.539s | 21.056s | 14.0 | 12.6 | 15.5 |
| Long 50K | 19.870s | 18.863s | 17.100s | 13.3 | 13.8 | 16.4 |
| Long 55K | 31.650s | 27.923s | 25.792s | 10.2 | 10.7 | 12.8 |
| Longlong 110K | 33.760s | 29.240s | 27.656s | 8.1 | 9.5 | 10.6 |
| Longlong 115K | 49.210s | 41.580s | 40.725s | 6.9 | 7.5 | 9.5 |

## Readout

- `Nemotron ON` was the strongest of the three speed profiles.
- Against the refreshed Qwen rerun, `Nemotron ON` improved throughput in all `10/10` scenarios.
- `Nemotron ON` improved TTFT in `8/10` scenarios.
- `Nemotron OFF` already beat Qwen on the long-context bands from `50K` through `115K`, but `Nemotron ON` widened that gap further.
- The largest latency win over Qwen was at `Longlong (115K)`: `40.725s` vs `49.210s`, a `-8.485s` TTFT delta.

## Caveat

This is a speed comparison, not a quality comparison.

- Qwen was run with deterministic sampling and thinking forced OFF.
- Nemotron used the model-card sampling pair `temperature = 1.0`, `top_p = 0.95`.
- So the result here is: on this macbook2 llama.cpp setup, Nemotron can be served fast enough to belong in the same tier as the recent Qwen rerun, and with thinking ON it often serves faster.
