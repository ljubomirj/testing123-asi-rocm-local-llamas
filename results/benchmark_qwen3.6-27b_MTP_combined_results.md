# llama-benchy Results for qwen3.6-27b (port 8081)

**Date:** 2026-05-09
**Tool:** llama-benchy 0.3.8.dev0
**Model:** qwen3.6-27b (Qwen3.6-27B-IQ4_NL.gguf)
**Server:** llama-server with --reasoning on, --grammar-file, --spec-default (ngram)
**GPU:** AMD ROCm0 (7900XTX 24GB)
**Context:** 163840
**Cache:** K=q8_0, V=q4_0, kv-unified
**Batch:** 2048, Ubatch: 512
**Latency Mode:** generation

---

## Results Table

| model       |   test |           t/s |     peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:------------|-------:|--------------:|-------------:|-----------------:|-----------------:|-----------------:|
| qwen3.6-27b |  pp512 | 158.55 ± 0.00 |              |   3490.40 ± 0.00 |   3292.38 ± 0.00 |   3490.40 ± 0.00 |
| qwen3.6-27b |  tg128 |  16.03 ± 0.00 | 20.00 ± 0.00 |                  |                  |                  |
| qwen3.6-27b | pp1024 |  96.37 ± 0.00 |              |  11073.07 ± 0.00 |  10875.05 ± 0.00 |  11073.07 ± 0.00 |
| qwen3.6-27b |  tg128 |  10.18 ± 0.00 | 16.00 ± 0.00 |                  |                  |                  |
| qwen3.6-27b | pp2048 |  53.90 ± 0.00 |              |  39234.68 ± 0.00 |  39036.66 ± 0.00 |  39234.68 ± 0.00 |
| qwen3.6-27b |  tg128 |   8.38 ± 0.00 | 18.00 ± 0.00 |                  |                  |                  |
| qwen3.6-27b | pp4096 |  29.17 ± 0.00 |              | 143957.62 ± 0.00 | 143759.60 ± 0.00 | 143957.62 ± 0.00 |
| qwen3.6-27b |  tg128 |   6.09 ± 0.00 | 19.00 ± 0.00 |                  |                  |                  |
| qwen3.6-27b | pp8192 |  15.27 ± 0.00 |              | 546754.43 ± 0.00 | 546567.90 ± 0.00 | 546754.43 ± 0.00 |
| qwen3.6-27b |  tg128 |   3.65 ± 0.00 | 16.00 ± 0.00 |                  |                  |                  |

---

## Notes

- **pp=16384 and pp=32768** timed out (>15 min socket read timeout). The server was still processing but too slowly.
- TG (token generation) speed degrades significantly with larger prompt sizes due to cache pressure and reduced batching.
- PP (prompt processing) speed drops from ~159 t/s at 512 tokens to ~15 t/s at 8192 tokens.
- The server has `--reasoning on` which may add overhead to each request.
- All runs used `--runs 1` and `--latency-mode generation`.

## Comparison to llama-batched-bench command

The comparable `llama-batched-bench` command would be:
```bash
build/bin/llama-batched-bench -m ~/llama.cpp/models/Ling-2.6-flash-IQ4_NL-bailing_hybrid-20260505-LJ.gguf -npp 512,1024,2048,4096,8192,16384,32768,65536 -ntg 128 -npl 1 -c 80000
```

Note: llama-benchy benchmarks via the HTTP API (OpenAI-compatible endpoint), which includes network/serialization overhead, reasoning mode overhead, and grammar enforcement. The native `llama-batched-bench` runs directly against the C++ engine without these overheads.

## Saved Result Files

- `/opt/ljubomir/llama.cpp/benchmark_qwen3.6-27b_MTP_20260509-190410.md` (pp=512..4096)
- `/opt/ljubomir/llama.cpp/benchmark_qwen3.6-27b_MTP_large_20260509-192402.md` (pp=8192)
- `/opt/ljubomir/llama.cpp/benchmark_qwen3.6-27b_MTP_latest2.log` (full log)
