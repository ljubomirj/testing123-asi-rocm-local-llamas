# MEMORY - Session History

## 2026-02-10 Session 1 - Setup, Benchmarks, Model Compatibility, DIY Quantization Plan
- **User**: Git worktree setup, standardized benchmarks for sglang vs llama.cpp. Test metrics: throughput, latency, cache hits, memory. Server start requested. Asked about alternative models (cyankiwi, TheHouseOfTheDude, Intel AutoRound). Interested in DIY quantization. Provided HF_TOKEN.
- **Agent**: Created worktrees, LEARNINGS.md, MEMORY.md, TESTING.md, bench_comprehensive.py. Attempted QuantTrio (OOM - needs 2 GPUs). Downloaded cyankiwi model (17GB, compressed-tensors format - incompatible with sglang). Researched alternatives. Created quantization guide and quantize_glm.py script using AutoAWQ with group_size=32 for self-quantization. Saved HF_TOKEN.

## 2026-02-10 Session 2 (Continued) - Comprehensive Investigation & Resolution
- **Agent**: Attempted multiple quantization approaches:
  - AutoAWQ: Failed (glm4_moe_lite not supported, deprecated)
  - llm-compressor: Failed (broke HIP ROCm 7.1.1 torch dependencies)
  - GPTQModel: Failed (corrupted venv with CUDA packages)
  - AMD Quark: Failed (no template for glm4_moe_lite architecture)
- **User**: Caught critical error - FP8 won't fit in 24GB (31B params × 1 byte = 31GB). Requested 4-bit quantization. Asked about GGUF support in sglang.
- **Agent**: Pivoted to MXFP4 (4-bit), but Quark still failed (no glm4_moe_lite support). Discovered sglang HAS GGUF support. User has existing Q4_K_XL (17GB, 200K context) and Q5_K_XL (21GB, 95K context) GGUF files from llama.cpp. Created flexible startup script. Attempted both main and rocm branches with GGUF.
- **Final Issue**: sgl_kernel library incompatible with ROCm 7.1.1 (undefined symbol: hsa_amd_memory_get_preferred_copy_engine). Blocks all sglang usage.
- **Conclusion**: GLM-4.7-Flash's custom glm4_moe_lite architecture has poor tooling support. User's working llama.cpp setup is best current solution. Options: rebuild sgl_kernel, try vLLM, or continue with llama.cpp.

## 2026-02-10 Session 3 (Continued) - vLLM Build & Final Resolution
- **User**: Clarified goal: "llama.cpp doesn't support concurrent support and radix caching well". Requested trying vLLM with Q5 GGUF. Specified: install from git source (not pip), establish llama.cpp baseline first.
- **Agent**:
  - Completed llama.cpp baseline benchmarks: 94-112 tok/s warm (9-20x better than expected 10 tok/s!), TTFT 0.03s warm, clear caching benefits
  - Built Triton for ROCm 3.4.0 from source (~27 min: 16 min LLVM download + 11 min compilation)
  - Built vLLM 0.15.2rc1 from source (~25 min: 2 min deps + 5 min CMake + 18 min C++ compilation)
  - Troubleshooting: Removed cupy-cuda12x, disabled CUDA platform detection (dual-GPU system with NVIDIA Quadro K620 + AMD 7900 XTX)
  - **Final blocker**: vLLM's GGUF loader doesn't support deepseek2 architecture (GLM-4.7-Flash uses deepseek2 MoE)
- **Conclusion**:
  - SGLang: ❌ ROCm 7.1.1 symbol incompatibility
  - vLLM: ❌ GGUF deepseek2 unsupported (but builds successfully for other models)
  - llama.cpp: ✅ Working excellently, best current option
  - Infrastructure built and ready for future use
  - Total time: ~4 hours (Triton 27min + vLLM 25min + troubleshooting)

## 2026-02-10 Session 4 (Continued) - Realistic Long-Context Benchmarking
- **User**: Caught critical flaw in baseline tests: "Was the context (95K) filled or empty?" Requested realistic test with 40K-50K context prefill + 10K-15K prompts. Asked agent to run tests and document results.
- **Agent**:
  - Created bench_longcontext.py with context prefilling capability
  - Discovered GLM-4.7-Flash uses `reasoning_content` field instead of `content` in streaming responses
  - Fixed benchmark script to handle both fields
  - Ran comprehensive tests: 40K prefill + 10K/15K prompts, 3 runs each
  - **CRITICAL FINDINGS**:
    - TTFT: 0.03s → 80-127s (2600-4200x slower with realistic context!)
    - Throughput: 94-112 tok/s → 4-7 tok/s (93-96% degradation)
    - Caching still excellent: 125s cold → 0.35s warm (357x speedup)
    - Super-linear degradation: 50K→55K causes 36% throughput loss
  - Created comprehensive documentation:
    - LONG_CONTEXT_RESULTS.md: Detailed analysis and recommendations
    - Updated LLAMA_CPP_TEST_ANALYSIS.md: Actual vs expected results
    - Updated LEARNINGS.md: Comparison table and key insights
- **Conclusion**:
  - Empty context tests (94-112 tok/s) were completely misleading
  - Real production performance: 4-7 tok/s for 50K-55K context
  - TTFT of 80-127s makes GLM-4.7-Flash unsuitable for interactive use
  - Best use case: Batch document processing with context reuse
  - Baseline established for future vLLM/SGLang comparison
  - User was 100% correct to question the unrealistic test conditions
- **User**: Asked for verification of llama-server parameters used in benchmark. Provided their exact command and understanding of what each parameter does. Asked if there are additional parameters to trade RAM for speed.
- **Agent**:
  - Confirmed benchmark used user's exact parameters (verified via ps aux)
  - Verified user's understanding is 100% correct (flash-attn, q8_0 cache, RAM caching)
  - Explained subtle difference: cache-prompt (VRAM) vs cache-ram (host RAM)
  - Explained 357x speedup: RAM cache stores prompt KV states, DMA transfer on cache hit
  - Created LLAMA_SERVER_PARAMETERS.md with comprehensive parameter analysis
  - Suggested optimizations: increase cache-ram to 64GB, batch-size to 4096, ubatch-size to 1024, threads to 16
  - Expected improvement: 15-30% throughput gain (6.9→8-9 tok/s)
  - Confirmed biggest bottleneck is GLM-4.7-Flash's reasoning tokens (80-127s TTFT), not llama.cpp config
- **User**: Approved testing optimized config and Q4 model
- **Agent**:
  - Started optimized server (4096 batch, 1024 ubatch, 64GB cache, metrics enabled)
  - Ran benchmark: 50K → 6.8 tok/s, 55K → 4.6 tok/s
  - **Critical finding**: No improvement from larger batches/cache (~0% change)
  - Root cause: Single-user workload doesn't benefit from batching
  - Memory bandwidth + O(n²) attention are the real bottlenecks
  - Created OPTIMIZATION_RESULTS.md with detailed analysis
  - Recommendation: Revert to baseline params (2048/512/32GB), test Q4 model next
  - Q4 expected: 10-15% improvement (smaller model = less memory bandwidth)
- **Agent**:
  - Created run_llama_q4.sh startup script
  - Started Q4 server (17GB model, 200K trained context)
  - Ran benchmark: 50K → 6.7 tok/s, 55K → 4.3 tok/s
  - **Critical finding**: Q4 performance identical to Q5 (-3%, within variance)
  - Root cause: KV cache (same size) dominates memory bandwidth, not model weights
  - Q4 advantage is NOT speed, but 2x larger context (200K vs 95K)
  - Created Q4_VS_Q5_RESULTS.md with comprehensive analysis
  - Recommendation: Use Q5 for quality, Q4 for contexts >95K (agentic workloads)
  - Optional next: Test Q4 at 100K-120K context (showcase its real advantage)
- **User**: Requested pushing Q4 to maximum context, double or max possible on VRAM
- **Agent**:
  - Restarted Q4 server with full 200K context (was limited to 95K)
  - Tested 190K context: Timed out (prefill >300s)
  - Tested 120K context: Timed out (TTFT >600s)
  - Tested 80K context: **SUCCESS!** 1.0 tok/s, TTFT 346s
  - **Critical findings**:
    - Scaling is worse than O(n²): 60% more context → 6.7x slower (exponent ~1.8)
    - 50K→80K: 6.7→1.0 tok/s, 79s→346s TTFT
    - Q4 @ 80K is usable but slow (1 tok/s = 30-60s per response)
    - >80K contexts become impractical (<1 tok/s, >400s TTFT)
  - Created SCALING_ANALYSIS.md with comprehensive scaling analysis
  - Conclusion: Q4's advantage is enabling 80-120K contexts that Q5 can't handle, not speed
  - Practical limit: 80K tokens for agentic workloads (1-2 tok/s acceptable for batch processing)

## 2026-02-10 Session 5 - MacBook2 Long-Context Benchmark Comparison
- **User**: Requested running same long-context benchmark (bench_longcontext.py) on macbook2 (Apple M2 Max 96GB) with glm-4.7-flash served by LM Studio (llama.cpp backend, port 1234). Goal: compare with gigul2 (AMD 7900 XTX) results.
- **Agent**:
  - Created bench_longcontext_macbook.py (stdlib-only, no requests dependency) for macbook portability
  - Ran 40K prefill + 10K/15K prompts, 1 run each (full 3-run benchmark would take ~3 hours)
  - **Results (macbook2 vs gigul2)**:
    - 50K context: TTFT 173s vs 80s (2.2x slower), throughput 0.93 vs 6.86 tok/s (7.4x slower)
    - 55K context: TTFT 266s vs 127s (2.1x slower), throughput 1.13 vs 4.36 tok/s (3.9x slower)
    - Actual decode speed: 2.1-2.6 tok/s vs 30-35 tok/s (14x slower)
    - Cache effectiveness preserved: 265s cold → 1.0s warm (255x speedup)
  - TTFT ratio (~2.1x) matches memory bandwidth ratio (M2 Max 400 GB/s vs 7900 XTX 960 GB/s)
  - Throughput gap (7-14x) much worse than bandwidth ratio, likely Metal backend vs Vulkan + LM Studio overhead
  - Created LONG_CONTEXT_RESULTS_MACBOOK2.md with full comparison analysis
  - Ran mid-context (10K prefill) benchmarks: 20K ctx → 67.7s TTFT, 3.3 tok/s; 25K ctx → 113.5s TTFT, 2.3 tok/s
  - Built raw llama.cpp (Metal) and ran both mid- and long-context benchmarks on port 8081 with Q6_K_XL model
  - Raw llama.cpp results nearly identical to LM Studio: 20K 66.8s/3.4, 25K 107.6s/2.4, 50K 165s/1.55, 55K 292s/1.06
  - Key finding: LM Studio adds negligible overhead vs raw llama.cpp. No practical difference
  - Renamed LONG_CONTEXT_RESULTS → CONTEXT_RESULTS_GIGUL2, created consolidated CONTEXT_RESULTS_MACBOOK2.md
  - gigul2 mid-context (20K, 25K) benchmarks still pending

## 2026-02-11 Session 6 - HIP ROCm 7.1.1 Backend Benchmarks (Transformative Results)
- **User**: llama.cpp rebuilt with HIP ROCm 7.1.1 backend, server running on port 8081 with same Q5_K_XL model. Requested running mid- and long-context benchmarks, update .md files, label "gigul2 llama.cpp (7900 XTX, HIP ROCm 7.1.1)".
- **Agent**:
  - Ran mid-context (10K prefill + 10K/15K prompts) and long-context (40K prefill + 10K/15K prompts) benchmarks
  - **HIP ROCm 7.1.1 results vs Vulkan (same hardware, same model, same params)**:
    - 20K: 39.2 vs 15.3 tok/s (2.6x), TTFT 8.8s vs 29.2s (3.3x)
    - 25K: 29.2 vs 10.2 tok/s (2.9x), TTFT 14.9s vs 51.4s (3.5x)
    - 50K: 21.8 vs 6.9 tok/s (3.2x), TTFT 20.6s vs 80.0s (3.9x)
    - 55K: 16.2 vs 4.4 tok/s (3.7x), TTFT 32.5s vs 126.3s (3.9x)
  - HIP ROCm 7.1.1 advantage grows with context (2.6x at 20K rising to 3.7x at 55K)
  - HIP ROCm 7.1.1 makes 50-55K context interactive (21-33s TTFT, 16-22 tok/s)
  - Updated CONTEXT_RESULTS.md, CONTEXT_RESULTS_GIGUL2.md, CONTEXT_RESULTS_GIGUL2_MIDCONTEXT.md
  - Saved JSONL: benchmark_gigul2_rocm_midcontext_results.jsonl, benchmark_gigul2_rocm_longcontext_results.jsonl

## 2026-02-11 Session 7 - Rename ROCm Backend Label to HIP ROCm 7.1.1
- **User**: Requested renaming all "ROCm" backend label references to "HIP ROCm 7.1.1" across 5 markdown files (CONTEXT_RESULTS.md, CONTEXT_RESULTS_GIGUL2.md, CONTEXT_RESULTS_GIGUL2_MIDCONTEXT.md, LEARNINGS.md, MEMORY.md). Careful not to change ROCm0 device names, ROCm/HIP technical terms, version references like "ROCm 7.1.1" in SGLang incompatibility notes, or filenames.
- **Agent**: Applied targeted sed replacements file by file, verified no standalone "ROCm" backend labels remain while preserving ROCm0, ROCm/HIP, version references, and filenames.
- **User**: Also requested longlong-context benchmark with 100K prefill. Loaded Q4_K_XL model with 190K context on port 8081.
- **Agent**:
  - Bumped bench_longcontext.py timeouts (300->900s prefill, 600->1200s request) for 100K+ context
  - Ran three tiers of benchmarks on Q4 HIP ROCm 7.1.1:
    - Mid (20K-25K): 39.6/28.9 tok/s, 8.6/14.7s TTFT (identical to Q5)
    - Long (50K-55K): 20.3/16.4 tok/s, 20.4/32.2s TTFT (identical to Q5)
    - Longlong (110K-115K): 11.2/7.9 tok/s, 44.0/67.3s TTFT (Q4 exclusive - exceeds Q5 95K limit)
  - Cold 100K prefill: 153.9s, warm: 0.43s (358x speedup)
  - Key finding: Q4 and Q5 identical speed at shared contexts; Q4 enables 2x more context (190K vs 95K)
  - 110K still interactive at 11.2 tok/s/44s TTFT
  - Updated CONTEXT_RESULTS.md with Q4 section, longlong tables, scaling analysis
- **User**: Switched server to hip-rocwmma build (llama.cpp compiled with rocWMMA support). Same Q4 model, 190K context. Requested same three tiers of benchmarks.
- **Agent**:
  - Ran mid/long/longlong benchmarks on hip-rocwmma build:
    - Mid (20K-25K): 42.3/30.6 tok/s, 8.6/14.5s TTFT
    - Long (50K-55K): 23.2/15.6 tok/s, 20.4/32.2s TTFT
    - Longlong (110K-115K): 10.9/8.5 tok/s, 44.1/67.5s TTFT
  - Key finding: rocWMMA provides **no meaningful speedup** (~1.04x average, within variance)
  - TTFT identical across all sizes; throughput diffs 0.95x-1.14x are noise
  - WMMA instructions don't benefit this MoE architecture's attention/decode workload
  - Updated CONTEXT_RESULTS.md with rocWMMA section and comparison table
  - Created fix_rocWMMA_build.sh documenting the rocWMMA build process

## 2026-02-11 Session 8 (Continued) - None-Context Benchmark
- **User**: Requested none-context benchmark (0-100 tokens, no prefill) to measure baseline speed.
- **Agent**:
  - Ran bench_longcontext.py with --no-prefill --prompt-tokens 25,50,100 on rocWMMA Q4 server
  - Results: ~30 tok/s throughput, sub-second TTFT (0.13-0.66s warm)
  - 25 tok: 30.3 tok/s, 0.58s TTFT (includes 1.4s cold start in avg)
  - 50 tok: 29.7 tok/s, 0.30s TTFT
  - 100 tok: 29.7 tok/s, 0.66s TTFT
  - Baseline decode speed is ~30 tok/s with zero context
  - Updated CONTEXT_RESULTS.md with none-context tier
- **User**: Asked if warm-cache decode could hit 100+ tok/s.
- **Agent**:
  - Created bench_cachehit.py using server-reported token counts (not chars/4 estimation)
  - Tests: send prompt cold (warm cache), then 5 repeat runs (cache hit)
  - Scenarios: 0 context, 1K, 5K, 10K context
  - **Answer: No.** Decode ceiling is ~28 tok/s, completely flat across all context sizes
  - TTFT on cache hit: 48-96ms (instant)
  - **Critical correction**: chars/token ratio is 3.1-5.4 (not 4.0), meaning all prior "tok/s" estimates were inflated 25-35%
  - "42 tok/s at 20K" was actually ~28 tok/s; "30 tok/s at none-context" was ~24 tok/s
  - Bottleneck is model's 40-layer forward pass per token, not KV cache attention
  - Updated CONTEXT_RESULTS.md with cache-hit section and corrected estimates
- **User**: Asked about --cache-ram (32GB) - is there an input→output level cache?
- **Agent**: Researched llama.cpp source. --cache-ram stores KV cache states in host RAM, NOT input→output pairs. No response-level caching exists. Decode ceiling (~28 tok/s) is the forward pass through all 40 layers per token.
- **User**: Do sglang or vllm have end-to-end cache?
- **Agent**: Researched both. SGLang has radix cache (KV state), vLLM has prefix caching (KV blocks). Neither has response-level caching in core engine. vLLM has external add-ons (Semantic Router, LMCache).
- **User**: Build sglang or vllm for 7900 XTX. Referenced llama.cpp ROCm build.
- **Agent**: SGLang GGUF is CUDA-only on ROCm. vLLM GGUF deepseek2 support was FIXED in commit 7f0be2aa2. Recommended vLLM.
- **User**: "Go ahead and try a vLLM + GGUF build." Build only, don't load model (GPU occupied).
- **Agent**:
  - Created venv ~/python3-venv/vllm-rocm/ (Python 3.13.7)
  - Installed torch 2.10.0+rocm7.1 from rocm7.1 index
  - Fixed amdsmi version mismatch (pip 6.4.3 → ROCm 7.1.1 local 26.2.0)
  - Fixed CMake too old (system 3.22.1 → venv 4.2.1 via PATH)
  - Fixed 6+ missing cmake packages by symlinking from ROCm 7.2.0
  - Fixed library version suffix mismatches (.70200 → .70101 symlinks)
  - **BUILD SUCCEEDED**: vLLM 0.16.0rc2.dev184+gbcd65c1f6, all 3 C extensions loaded
  - Fixed dual-GPU platform conflict (Quadro K620 + 7900 XTX): patched platform detection to prefer ROCm when PyTorch built with HIP
  - **vllm CLI fully working**: serve, chat, bench, collect-env all operational
  - GGUF support confirmed: gguf_loader and gguf quantization modules present

## 2026-02-14 Session 9 - vLLM GGUF Success & MLA Attention
- **User**: Continued from previous session (qwe2) where vLLM built successfully but couldn't load GGUF model. Previous session died at MLA attention error.
- **Agent**:
  - Investigated previous attempts from qwe/qwe1 logs
  - vLLM already had patches applied: gguf_utils.py had deepseek2 GGUF mapping patches and transformers CONFIG_MAPPING patch
  - config.json already had MLA parameters (kv_lora_rank, q_lora_rank, qk_nope_head_dim, v_head_dim) and MoE parameters
  - **SUCCESS**: vLLM server started successfully on port 8081
  - Architecture resolved as DeepseekV2ForCausalLM (deepseek2 architecture in GGUF)
  - Using Triton MLA backend (flash_attn not available on ROCm)
  - Model loading: 16.61 GiB, 73 seconds
  - KV cache: 62,688 tokens (3.16 GiB)
  - CUDA graphs captured successfully
  - Server fully operational with OpenAI-compatible API
  - **Issue**: Generated text is garbled (tokenizer issue with GGUF) - needs investigation
  - Used venv: ~/python3-venv/vllm-rocm/
  - PyTorch: 2.10.0+rocm7.1
  - Transformers: 5.1.0 (upgraded from 4.57.6)
  - vLLM version: 0.16.0rc2.dev184+gbcd65c1f6
  - Startup command: `PYTORCH_ROCM_ARCH=gfx1100 HIP_VISIBLE_DEVICES=0 python3 -m vllm.entrypoints.openai.api_server --model /home/ljubomir/rocm-glm-4.7-flash/vllm-model/GLM-4.7-Flash-UD-Q4_K_XL.gguf --hf-config-path /home/ljubomir/rocm-glm-4.7-flash/vllm-model --tokenizer /home/ljubomir/rocm-glm-4.7-flash/vllm-model --port 8081 --dtype half --max-model-len 4096`

## 2026-02-14 Session 10 - vLLM GLM-4.7-Flash Comprehensive Investigation (Final Conclusions)
- **User**: Provided Unsloth FP8 documentation (https://unsloth.ai/docs/models/glm-4.7-flash), asked to continue investigating vLLM options. Mentioned transformers-src checkout available for research.
- **Agent**:
  - Researched transformers commits: Found GLM-4.7-Flash support added Jan 2026 (76732b4e71), recent TP fixes (e5fa6fee54, 2ac7fed2f3)
  - Extracted correct GLM-4.7-Flash config from HF: num_key_value_heads=20 (not 1!), MLA params confirmed
  - Tried Unsloth FP8 Dynamic model → NotImplementedError: "No FP8 MoE backend supports ROCm deployment configuration"
  - Tried without --kv-cache-dtype fp8 → NotImplementedError: "TritonMLA V1 with FP8 KV cache not yet supported"
  - Tried cyankiwi AWQ-4bit → ValueError: WNA16 group_size 32 not supported (needs 128 on ROCm)
  - Tried original HF model (zai-org/GLM-4.7-Flash) → OOM (60GB BF16 too large for 24GB GPU)
  - Investigated vLLM source: FP8 MoE kernels (Marlin, DeepGEMM, FlashInfer) CUDA-only, AITER limited on ROCm
  - Root cause identified: GGUF deepseek2→DeepseekV2ForCausalLM mapping incompatible with actual Glm4MoeLiteForCausalLM
  - **Final conclusions documented in LEARNINGS.md**:
    1. GGUF: Architecture mismatch cannot be fixed via config (tensor names/structures incompatible)
    2. FP8 MoE: Not supported on ROCm (CUDA-only kernels)
    3. compressed-tensors: Limited ROCm support (group size restrictions)
    4. Unquantized model: Exceeds single 24GB GPU
  - **Recommendation**: Use llama.cpp which works excellently (~30 tok/s, proper tokenizer, 95K context)
  - Created comprehensive investigation report documenting all vLLM ROCm limitations for GLM-4.7-Flash
  - Updated LEARNINGS.md with full technical analysis and comparison tables

## 2026-02-15 Session 11 - llama.cpp hip-rocwmma-new Build Benchmarks
- **User**: Requested running full benchmark suite on new llama.cpp build "build-gigul2-hip-rocwmma-new" (rocmWMA support). Server running on port 8081 with glm-4.7-flash Q4_K_XL. Label: "llama.cpp hip-rocwmma-new linux glm-4.7-flash". Test none-, small-, mid-, long-, longlong-context benchmarks.
- **Agent**:
  - Ran comprehensive benchmark suite on http://192.168.1.251:8081
  - **none-context (no prefill, 25/50/100 tokens)**:
    - 25 tok: 83.4 tok/s, 0.394s TTFT (first run had cold start 1.076s)
    - 50 tok: 88.1 tok/s, 0.069s TTFT
    - 100 tok: 91.1 tok/s, 0.095s TTFT
  - **small-context (10K prefill + 10K/15K prompts = 20K-25K total)**:
    - 20K: 38.3 tok/s, 8.920s TTFT
    - 25K: 29.5 tok/s, 15.230s TTFT
  - **mid-context (10K prefill + 10K/15K prompts = 20K-25K total)**:
    - 20K: 41.5 tok/s, 9.126s TTFT
    - 25K: 31.1 tok/s, 15.230s TTFT
  - **long-context (40K prefill + 10K/15K prompts = 50K-55K total)**:
    - 50K: 21.6 tok/s, 20.792s TTFT
    - 55K: 15.0 tok/s, 32.690s TTFT
  - **longlong-context (100K prefill + 10K/15K prompts = 110K-115K total)**:
    - 110K: 11.5 tok/s, 44.235s TTFT
    - 115K: 8.1 tok/s, 67.687s TTFT
  - Results saved to: benchmark_results_llama-cpp-hip-rocwmma-new_2026-02-15/
  - **Key finding**: hip-rocwmma-new build shows expected performance - similar to previous hip-rocwmma build
  - Cache effectiveness maintained: warm prefill 0.17-0.45s (vs cold 155s for 100K)

## 2026-02-15 Session 12 - Qwen3-Coder-Next MoE Offloading Benchmark
- **User**: Pulled latest llama.cpp with Qwen3-Coder-Next optimizations (commits 1725e316c, 079feab9e). Built new hip-rocwmma version.
- **Agent**:
  - Built `/data1/data/llama.cpp/build-gigul2-hip-rocwmma-new/` with rocWMMA_FATTN=ON, MMQ_MFMA=ON
  - Benchmarked Qwen3-Coder-Next-UD-Q5_K_XL (80B params, 512 experts, 10 active per token)
  - **Key Finding**: `--n-cpu-moe 29` is optimal for 24GB VRAM (vs Reddit's 27 for 32GB)
  - `--n-cpu-moe 28` OOMs; `--n-cpu-moe 29` fits with 13.58 tok/s generation (20 threads)
  - Each layer moved from CPU to GPU adds ~0.3-0.5 tok/s
  - Prompt processing: 114 t/s; Generation: 13.58 t/s
  - Created `bench_qwen3_results/QWEN3_BENCHMARK_SUMMARY.md` with full results
- **Model**: 53GB total (3 GGUF parts), 48 layers, 262K context
- **Recommendation**: Use `--n-cpu-moe 29 --threads 20 --flash-attn on` for production

- **User**: Server restarted with Qwen3 on port 8081. Requested full benchmark suite (none-, small-, mid-, long-, longlong-context). Corrected prefill sizes: None=0, Small=2K, Mid=10K, Long=40K, Longlong=100K.
- **Agent**:
  - Ran full benchmark suite on http://192.168.1.251:8081 with corrected prefill sizes
  - **none-context (0 prefill, 25/50/100 tokens)**:
    - 25 tok: 11.3 tok/s, 1.072s TTFT
    - 50 tok: 11.2 tok/s, 1.164s TTFT
    - 100 tok: 12.5 tok/s, 1.355s TTFT
  - **small-context (2K prefill + 10K/15K = 12K-17K total)**:
    - 12K: 7.4 tok/s, 27.684s TTFT
    - 17K: 6.3 tok/s, 40.966s TTFT
  - **mid-context (10K prefill + 10K/15K = 20K-25K total)**:
    - 20K: 7.2 tok/s, 31.095s TTFT
    - 25K: 5.6 tok/s, 45.841s TTFT
  - **long-context (40K prefill + 10K/15K = 50K-55K total)**:
    - 50K: 6.0 tok/s, 41.999s TTFT
    - 55K: 5.1 tok/s, 61.535s TTFT
  - **longlong-context (100K prefill + 10K/15K = 110K-115K total)**:
    - 110K: 4.7 tok/s, 64.590s TTFT
    - 115K: 4.0 tok/s, 94.448s TTFT
  - Results saved to: benchmark_results_llama-cpp-hip-rocwmma_qwen3_2026-02-15/
  - Created SUMMARY.md with GLM-4.7-Flash comparison
  - **Key finding**: Qwen3-Coder-Next (80B MoE) is ~3-6x slower than GLM-4.7-Flash (30B)
    - Baseline decode: ~11-12 tok/s vs GLM's ~88-91 tok/s
    - MoE overhead (512 experts, 10 active) + 2.7x larger model = significant slowdown

## 2026-02-16 Session 13 - GLM-4.7-Flash MLX-8bit Benchmarks on macbook2
- **User**: Requested running benchmark suite on GLM-4.7-Flash served by LM Studio (MLX format) on macbook2. All context tiers (none/small/mid/large/largelarge).
- **Agent**:
  - Found model loaded in LM Studio: `zai-org/glm-4.7-flash` (MLX-8bit, 31.84 GB, `glm4_moe_lite` arch)
  - Discovered MLX backend crash at ~15K-17K tokens: `AttributeError: 'list' object has no attribute 'swapaxes'`
  - Updated bench_longcontext_macbook.py with crash detection, auto-reload via `lms` CLI (unload/load), retry logic
  - Combined context+prompt into single user message (multi-turn crashes the model)
  - Context length 150K caused instability (crash even at 10K); reverted to 32K
  - **Results (none-context only, larger tiers all crash)**:
    - 10K: TTFT=31.3s, 10.2 tok/s (3 runs)
    - 15K: Intermittent crash (worked in session A, crashed in session B)
  - **vs gigul2 Q4**: 2.2x slower TTFT, 2.7x slower throughput (matches bandwidth ratio)
  - Created CONTEXT_RESULTS_MACBOOK2_LMSTUDIO_MLX8BIT_GLM47.md
  - **Conclusion**: MLX-8bit GLM-4.7-Flash limited to ~10K context due to MLX kernel bug

## 2026-02-17 Session 14 - Fix rpath + joyai-llm-flash Benchmarks on macbook2
- **User**: Fix rpath in llama.cpp build.macbook2-metal binaries (renamed from build/). Then benchmark joyai-llm-flash Q6_K served by llama.cpp Metal on port 8081. Run none/small/mid/large tiers (skip largelarge).
- **Agent**: Fixed rpath using install_name_tool: @executable_path for binaries, @loader_path for dylibs. Saved script as fix_rpath_macbook2_metal.sh. Ran all 4 context tiers (3 runs each):
  - none: 10K=35.7s/4.9tok/s, 15K=34.0s/4.2tok/s
  - small: 20K=79.2s/2.6tok/s, 25K=128.7s/2.2tok/s
  - mid: 50K=193.3s/1.2tok/s, 55K=300.7s/0.9tok/s
  - large: 90K=453.7s/0.7tok/s, 95K=563.2s/0.5tok/s
  - Zero crashes across all tiers. Total benchmark time: ~3.5 hours.
  - Created CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_JOYAI.md

## 2026-02-18 Session 15 - BarraCUDA Assessment + Deep Dive into sglang/vllm/transformers gfx1100 Support
- **User**: Found BarraCUDA (CUDA-to-GFX11 compiler, 15K lines C99, no LLVM). Built binary. Asked if it could help port CUDA code to 7900 XTX for sglang/vllm/transformers. Also noted ROCm 7.1.1 is fixed (7.2.0 requires kernel upgrade).
- **Agent**:
  - Assessed BarraCUDA: impressive project but wrong tool for the job. Handles simple .cu files, not the massive C++/CUDA template metaprogramming in ML frameworks. Blockers are architectural gatekeeping and missing implementations, not compilation.
  - Launched 3 parallel exploration agents to audit sglang-src, vllm-src, transformers-src for gfx1100/RDNA3 support.
  - Confirmed system: ROCm 7.1.1 + 7.2.0 installed, gfx1100 detected as Agent 2, PyTorch not in base python (needs venv).
  - **SGLang findings**: gfx1100 explicitly in supported_targets list. FP8 disabled for gfx1100 (hardware). AITER backend auto-selected for HIP. BUT: 3rdparty build script omits gfx1100 from default targets.
  - **vLLM findings**: gfx1100 in CMake arch list, device ID mapped. CRITICAL: AITER locked to gfx9 only (_aiter_ops.py on_gfx9() check) - no fused MOE, RMSNorm, FP8 linear on gfx1100. Custom paged attention restricted (head_size=128 only, gqa_ratio>=3). Flash Attention Triton for RDNA exists but needs env var + package. CI tests only on MI325.
  - **Transformers findings**: Least problematic. SDPA works on ROCm. ROCm detection works. FA3 blocked by hardcoded CUDA compute capability check. Docker only builds gfx942. Eager attention always works.
  - **Conclusion**: BarraCUDA can't help. Real blockers are: (1) GGUF arch mismatch deepseek2→Glm4MoeLite, (2) AITER gfx9-only gatekeeping, (3) FP8 MoE CUDA-only, (4) compressed-tensors group_size restrictions. Identified 4 actionable fix paths, with GGUF arch mapping fix being most tractable.

## 2026-02-21 Session 15 - Fix rpath (rebuild) + Qwen3-Coder-Next Benchmarks on macbook2
- **User**: Fix rpath again (new llama.cpp rebuild b8393). Then benchmark Qwen3-Coder-Next Q5_K_XL (80B MoE) on llama.cpp Metal b8393 port 8081. Run none/small/mid tiers (skip large/largelarge).
- **Agent**: Ran fix_rpath_macbook2_metal.sh (41 bins + 6 dylibs fixed). Ran 3 tiers:
  - none: 10K=17.1s/10.9tok/s, 15K=12.1s/13.2tok/s
  - small: 20K=22.4s/11.2tok/s, 25K=32.8s/8.8tok/s
  - mid: 50K=28.8s/9.0tok/s, 55K=42.3s/7.3tok/s
  - Zero crashes. Total benchmark time: ~17 min.
  - **Key finding**: macbook2 Metal b8393 beats gigul2 HIP ROCm at all context sizes (15-24% faster TTFT, 30-44% faster throughput). Unified memory advantage: 96GB fits full 57GB model without CPU offloading, while gigul2 must offload 33 experts to CPU.
  - Created CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_QWEN3_CODER_NEXT.md

## 2026-02-26 Session 17 - LongCat-Flash-Lite 69B MLX 5.5-bit Benchmarks
- **User**: Start mlx_lm server for LongCat-Flash-Lite 69B (inferencerlabs/LongCat-Flash-Lite-MLX-5.5bit) on port 8081 and run full benchmark suite (none/small/long/longlong tiers).
- **Agent**: Started mlx_lm.server 0.30.7 on port 8081. Ran 4 tiers:
  - none: 25tok=0.4s/52.9tok/s, 50tok=0.5s/53.4tok/s, 100tok=0.8s/40.8tok/s
  - small (10K prefill): 20K=44.7s/9.5tok/s, 25K=60.2s/7.3tok/s
  - long (40K prefill): 50K=146.7s/3.5tok/s, 55K=175.2s/3.6tok/s
  - longlong (100K prefill): CRASH — Metal GPU Internal Error at ~45K/55K tokens (OOM, ~50GB model + KV cache)
  - **Key finding**: 69B LongCat at 50K context (3.5 tok/s) outperforms 9B GLM-4.7-Flash on vLLM-MLX (2.7 tok/s) — MLA attention more efficient. But 15x slower than baseline (53 tok/s). 100K context impossible at 5.5-bit on 92GB.
  - Had to fix mlx_lm.server model name issue ("default" causes HF lookup; must use full path).
  - Created CONTEXT_RESULTS_MACBOOK2_MLX_LONGCAT_FLASH_LITE.md

## 2026-02-27 Session 18 - Re-run GLM-4.7-Flash Baseline Benchmarks with Fixed Small/Mid Prefill
- **User**: Requested re-running bench_longcontext.py benchmark suite from session 11. Identified bug: Small and Mid both used identical `--prefill-tokens 10000`. Fix to differentiate: Small=5K prefill, Mid=20K prefill. Initially tried with different model (glm-4.7-flash-claude-4.5-opus.q4_k_m.gguf) — was ~10x slower (93s TTFT at 15K context vs 9s with Q4_K_XL). Switched back to GLM-4.7-Flash-UD-Q4_K_XL.gguf.
- **Agent**:
  - Fixed run_all_benchmarks.sh: Small 5K prefill (15K-20K total), Mid 20K prefill (30K-35K total)
  - Restarted llama-server with Q4_K_XL model on port 8081 (same params as session 11)
  - Ran all 5 tiers:
    - none: 25tok=0.309s/85.6tok/s, 50tok=0.070s/87.4tok/s, 100tok=0.092s/89.9tok/s
    - small (5K prefill): 15K=7.226s/42.2tok/s, 20K=12.457s/30.8tok/s
    - mid (20K prefill): 30K=13.125s/30.2tok/s, 35K=21.199s/21.3tok/s
    - long (40K prefill): 50K=20.938s/21.5tok/s, 55K=33.023s/15.8tok/s
    - longlong (100K prefill): 110K=44.565s/11.3tok/s, 115K=68.169s/7.8tok/s
  - Small and Mid now meaningfully differentiated (5K vs 20K prefill)
  - Results consistent with session 11 baseline for shared context sizes
  - Results saved to: benchmark_results_llama-cpp-hip-rocwmma-new_2026-02-27/

## 2026-02-27 Session 18b - Build latest llama.cpp b8456 + Benchmark Comparison
- **User**: Pull latest llama.cpp, build ROCm 7.1.1 + rocWMMA into ./build, kill old server, restart with new build, re-run all benchmarks.
- **Agent**:
  - Pulled 28 new upstream commits (mxfp4 repack, server fixes, kv-cache fixes, AMX fix, etc.)
  - Built successfully: version 8456 (e729d4ed2), HIP + rocWMMA FATTN ON, gfx1100
  - Killed old server (build-gigul2-hip-rocwmma, older version), started new build/bin/llama-server
  - Ran all 5 tiers with GLM-4.7-Flash-UD-Q4_K_XL.gguf:
    - none: 25tok=0.223s/85.2tok/s, 50tok=0.069s/89.5tok/s, 100tok=0.093s/85.6tok/s
    - small (5K prefill): 15K=7.227s/43.4tok/s, 20K=12.801s/31.9tok/s
    - mid (20K prefill): 30K=13.083s/30.2tok/s, 35K=21.234s/19.9tok/s
    - long (40K prefill): 50K=20.958s/20.3tok/s, 55K=34.199s/14.4tok/s
    - longlong (100K prefill): 110K=44.561s/11.5tok/s, 115K=68.240s/8.0tok/s
  - **Conclusion**: No meaningful speed change from b8456 vs old build. All numbers within run-to-run variance. The 28 upstream commits had no perf-relevant HIP/ROCm changes.
  - Results saved to: benchmark_results_llama-cpp-hip-rocwmma-new-b8456_2026-02-27/

## 2026-02-27 Session 18c - Qwen3.5-35B-A3B-UD-Q4_K_M Benchmark on gigul2
- **User**: Test new Qwen3.5-35B-A3B model (19GB Q4_K_M, 2GB larger than GLM 17GB). Run same 5-tier benchmark suite. Check for OOM.
- **Agent**:
  - Server started cleanly: 18.6GB on GPU, 4 slots, 130K ctx, no OOM
  - Ran all 5 tiers:
    - none: 25tok=1.699s/65.8tok/s, 50tok=0.148s/73.4tok/s, 100tok=0.189s/79.4tok/s
    - small (5K prefill): 15K=7.166s/45.0tok/s, 20K=11.536s/31.5tok/s
    - mid (20K prefill): 30K=11.717s/31.3tok/s, 35K=18.322s/24.4tok/s
    - long (40K prefill): 50K=18.430s/24.5tok/s, 55K=28.104s/17.5tok/s
    - longlong (100K prefill): 110K=37.336s/13.0tok/s, 115K=55.577s/9.8tok/s
  - **No OOM** at any context size including 115K
  - **Key finding**: Qwen3.5-35B-A3B is faster than GLM-4.7-Flash at all context sizes despite being 2GB larger:
    - TTFT: 10-20% faster across all tiers (most dramatic at longlong: 37s vs 45s at 110K)
    - Throughput: ~15% higher at mid/long/longlong contexts
    - Baseline (none-context): ~15% slower (73-79 vs 85-90 tok/s) — MoE routing overhead at small context
    - Cold prefill 100K: 126s vs 157s (20% faster prompt processing)
  - Results saved to: benchmark_results_qwen35-35b-a3b-q4km_2026-02-27/

## 2026-02-27 Session 18d - Qwen3.5-27B Dense Q5_K_XL Benchmark on gigul2
- **User**: Test Qwen3.5-27B dense model (Q5_K_XL, 19GB). Download from HuggingFace, run same 5-tier benchmark suite.
- **Agent**:
  - Downloaded Qwen3.5-27B-UD-Q5_K_XL.gguf (19GB) from unsloth/Qwen3.5-27B-GGUF
  - Server loaded: 17.8GB on GPU + 834MB CPU, 4 slots, 130K ctx
  - Warning: "failed to fit params to free device memory" but continued with --gpu-layers all
  - **No OOM** at any context size including 115K
  - Ran all 5 tiers:
    - none: 25tok=0.233s/27.4tok/s, 50tok=0.263s/25.4tok/s, 100tok=0.346s/26.4tok/s
    - small (5K prefill): 15K=17.706s/15.0tok/s, 20K=29.486s/11.4tok/s
    - mid (20K prefill): 30K=28.632s/12.1tok/s, 35K=44.586s/9.2tok/s
    - long (40K prefill): 50K=44.700s/8.9tok/s, 55K=66.119s/7.1tok/s
    - longlong (100K prefill): 110K=89.582s/5.4tok/s, 115K=134.974s/4.0tok/s
  - **Key finding**: Dense 27B is ~3x slower than MoE models at all tiers. Not competitive for inference speed.
    - Baseline: 26 tok/s vs 73-87 tok/s (MoE models)
    - 55K context: 66s TTFT / 7.1 tok/s vs 28s / 17.5 tok/s (Qwen MoE) or 34s / 14.4 tok/s (GLM)
    - 115K context: 135s TTFT / 4.0 tok/s vs 56s / 9.8 tok/s (Qwen MoE)
    - Cold 100K prefill: 301s vs 126s (Qwen MoE) vs 157s (GLM)
  - Results saved to: benchmark_results_qwen35-27b-dense-q5kxl_2026-02-27/

## 2026-02-28 Session 18e - Qwen3.5-27B Dense Q4_K_XL Benchmark (VRAM-fit Control Test)
- **User**: Q5 model had 834MB CPU spill - test Q4_K_XL (16GB) to see if VRAM fit matters.
- **Agent**:
  - Downloaded Qwen3.5-27B-UD-Q4_K_XL.gguf (16GB) from unsloth
  - Server loaded: 15.3GB GPU + 682MB CPU. Still some CPU spill but less than Q5 (834MB)
  - Ran all 5 tiers:
    - none: 25tok=0.233s/28.1tok/s, 50tok=0.260s/27.8tok/s, 100tok=0.323s/27.5tok/s
    - small (5K prefill): 15K=17.275s/17.3tok/s, 20K=28.187s/12.1tok/s
    - mid (20K prefill): 30K=28.083s/12.6tok/s, 35K=44.028s/10.1tok/s
    - long (40K prefill): 50K=42.957s/10.3tok/s, 55K=65.725s/7.0tok/s
    - longlong (100K prefill): 110K=89.881s/5.5tok/s, 115K=133.241s/4.4tok/s
  - **Conclusion**: Q4 vs Q5 performance is virtually identical across all tiers.
    - Baseline: 27.8 vs 25.4 tok/s (+9%, within noise for quantization difference)
    - TTFT: within 2-3% at all sizes
    - The CPU spill (682-834MB) is NOT the bottleneck — it's the dense 27B forward pass
    - Quantization doesn't help because decode is compute-bound, not memory-bound
  - Results saved to: benchmark_results_qwen35-27b-dense-q4kxl_2026-02-28/

## 2026-02-26 Session - Qwen3.5-122B-A10B Benchmark on macbook2 Metal
- **User**: Benchmark Qwen3.5-122B-A10B-UD-Q3_K_XL (~51GB GGUF) on llama.cpp Metal using bench_longcontext.py framework.
- **Agent**: Started llama-server on port 8081 with --parallel 1, 262K ctx, flash-attn, q8_0 KV, --kv-unified. Ran 5 benchmark tiers:
  - none: 25tok=0.78s/15.1tok/s, 50tok=1.0s/13.7tok/s, 100tok=1.21s/15.0tok/s
  - small (10K prefill): 20K=58.2s/6.2tok/s, 25K=95.5s/4.6tok/s
  - mid (repeat): 20K=59.5s/6.1tok/s, 25K=90.5s/4.8tok/s
  - long (40K prefill): 50K=79.3s/4.6tok/s, 55K=120.5s/3.2tok/s
  - longlong (100K prefill): CRASH — Metal GPU Internal Error (command buffer status 5) at ~58K tokens into prefill. Same failure pattern as LongCat-Flash-Lite.
  - **Key finding**: 122B MoE model at Q3_K_XL gives ~15 tok/s baseline, degrades to 3.2 tok/s at 55K context. Prompt processing 69.5 tok/s. Practical context limit ~55K on 96GB M2 Max.
  - Created run_llama_qwen35_122b_macbook2.sh and CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_QWEN35_122B_A10B.md

## 2026-02-27 Session 19 - Re-download & Re-benchmark Qwen3.5-122B-A10B Refreshed GGUF
- **User**: Re-download 3 GGUF files (UD-Q3_K_XL) from unsloth/Qwen3.5-122B-A10B-GGUF (possibly refreshed by danielhanchen 3 days ago). Then re-run all 5 benchmark tiers.
- **Agent**:
  - Downloaded via `hf download` (files 1+3) then curl (file 2, 50GB stalled on HF CLI). Total ~51GB (10MB + 47GB + 4.3GB).
  - Symlinked into ~/llama.cpp/models/ for backward compat with run script.
  - Started llama-server (build 8393, Metal, same params as session 18-Qwen).
  - Ran all 5 tiers with corrected prefill sizes (None=0, Small=5K, Mid=20K, Long=40K, Longlong=100K):
    - none: 25tok=0.69s/17.5tok/s, 50tok=0.90s/15.7tok/s, 100tok=1.19s/15.5tok/s
    - small (5K prefill): 15K=49.1s/6.7tok/s, 20K=69.9s/5.4tok/s
    - mid (20K prefill): 30K=54.5s/6.2tok/s, 35K=80.8s/5.1tok/s
    - long (40K prefill): 50K=64.6s/5.4tok/s, 55K=96.3s/4.0tok/s
    - longlong (100K prefill): 110K=97.1s/3.5tok/s, 115K=153.5s/2.5tok/s
  - **CRITICAL: Longlong no longer crashes!** Previously Metal GPU Internal Error at ~58K tokens into 100K prefill. Refreshed quant handles 115K context fine.
  - **15-25% faster** at long context vs old quant (50K: 4.6→5.4 tok/s, 55K: 3.2→4.0 tok/s)
  - **16% faster baseline** (17.5 vs 15.1 tok/s at 25 tokens)
  - Cold 100K prefill: 392s, warm: 7.4s (53x speedup)
  - Results saved to: benchmark_results_llama_cpp_metal_qwen35_122b_refreshed_2026-02-27/

## 2026-03-01 Session 20 - Qwen3.5-35B-A3B MoE Q8_K_XL Benchmarks on macbook2 Metal
- **User**: Run standard benchmark suite (None/Small/Mid/Long/LongLong) on macbook2 with Qwen3.5-35B-A3B-UD-Q8_K_XL.gguf (MoE, 35B params, 8 experts active, ~36GB). Use llama.cpp llama-server (Metal build), port 8081. Test with 6 threads (default) then --parallel 1 for max latency. Record results in CONTEXT_RESULTS.md and create dedicated results file.
- **Agent**:
  - Started llama-server (build 8466, Metal) with 6 threads configuration
  - Ran all 5 benchmark tiers with corrected prefill sizes:
    - none (0 prefill): 25tok=0.29s/34.5tok/s, 50tok=0.33s/28.7tok/s, 100tok=0.43s/31.0tok/s
    - small (10K prefill): 12K=4.1s/23.0tok/s
    - mid (20K prefill): 25K=9.3s/17.2tok/s
    - long (40K prefill): 50K=22.6s/11.4tok/s, 55K=31.5s/10.1tok/s
    - longlong (60K prefill): 70K=25.7s/10.5tok/s, 75K=38.1s/8.9tok/s
  - Restarted server with --parallel 1 and reran all 5 tiers:
    - none: 25tok=0.27s/35.4tok/s, 50tok=0.31s/33.7tok/s, 100tok=0.40s/28.2tok/s
    - small: 12K=3.6s/24.5tok/s
    - mid: 25K=8.9s/17.8tok/s
    - long: 50K=22.5s/11.4tok/s, 55K=32.9s/9.4tok/s
    - longlong: 70K=25.8s/10.4tok/s, 75K=38.5s/8.4tok/s
  - **Key finding**: Minimal difference between 6-thread and 1-thread modes (<10% variance). Metal backend on M2 Max is already well-optimized for single-threaded operation. MoE models with Q8 quantization don't benefit from parallel processing.
  - Qwen3.5-35B-A3B is ~7.7x faster than GLM-4.7-Flash (Q4) at 50K context (22.6s vs 173s TTFT)
  - Created CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_QWEN35_35B_A3B.md and updated CONTEXT_RESULTS.md

## 2026-03-01 Session 21 - Qwen3.5-27B Dense Q8_K_XL Benchmarks on macbook2 Metal
- **User**: Benchmark Qwen3.5-27B-UD-Q8_K_XL.gguf (dense, 27B, ~29GB) on macbook2 with llama.cpp Metal. Run full benchmark suite (None/Small/Mid/Long/LongLong). Record results and create dedicated results file.
- **Agent**:
  - Started llama-server (build 8466, Metal) with 6 threads configuration
  - Ran all 5 benchmark tiers:
    - none (0 prefill): 50tok=0.90s/6.8tok/s, 100tok=1.55s/5.9tok/s
    - small (5K prefill): 15K=61.86s/3.9tok/s, 20K=106.01s/2.7tok/s
    - mid (20K prefill): 30K=77.45s/3.3tok/s, 35K=114.52s/2.7tok/s
    - long (40K prefill): 50K=83.36s/3.1tok/s, 55K=129.27s/2.4tok/s
    - longlong (100K prefill): 110K=118.62s/2.3tok/s, 115K=160.14s/2.0tok/s
  - **Key finding**: Dense 27B Q8 is ~4-5x slower than MoE 35B Q8 at all context sizes (6.8 vs 28.7 tok/s baseline)
  - Dense model compute is the bottleneck; MoE architecture provides significant performance advantage despite larger model size
  - Created CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_QWEN35_27B.md and updated CONTEXT_RESULTS.md

## 2026-03-03 Session 22 - Step-3.5-Flash-REAP-121B-A11B MoE Q4_K_S Benchmarks on macbook2 Metal
- **User**: Benchmark Step-3.5-Flash-REAP-121B-A11B.Q4_K_S.gguf (MoE, 121B, ~64GB) on macbook2 with llama.cpp Metal. Run full benchmark suite (None/Small/Mid/Long/LongLong). Record results and create dedicated results file.
- **Agent**:
  - Started llama-server (build 8466, Metal) with 6 threads configuration
  - Ran all 5 benchmark tiers:
    - none (0 prefill): 50tok=0.72s/27.5tok/s, 100tok=1.07s/24.2tok/s
    - small (5K prefill): 15K=40.71s/9.6tok/s, 20K=58.33s/7.4tok/s
    - mid (20K prefill): 30K=46.04s/8.5tok/s, 35K=70.61s/6.5tok/s
    - long (40K prefill): 50K=56.40s/7.6tok/s, 55K=89.83s/5.3tok/s
    - longlong (100K prefill): 110K=122.03s/3.4tok/s (only 1 successful run)
  - **Server crashed** at 115K context - memory pressure (64GB model + 100K KV cache exceeds 96GB RAM)
  - **Key finding**: 121B MoE Q4 has similar baseline to 35B-A3B MoE Q8 (27.5 vs 28.7 tok/s), but 2.5x higher TTFT at long context
  - 110K is practical limit for this 121B model on 96GB RAM
  - Created CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_STEP35_FLASH_REAP_121B.md and updated CONTEXT_RESULTS.md

## 2026-03-03 Session 24 - vLLM-MLX Setup with IQuest-Coder-V1-14B-Thinking
- **User**: Setup vllm-mlx, download IQuest-Coder-V1-14B-Thinking model in MLX format, run on port 8082, document everything for future restarts.
- **Agent**:
  - Created .venv-vllm-mlx with uv venv
  - Installed vllm-mlx 0.2.6 from local repo (editable mode) - 102 packages including mlx 0.31.0, mlx-lm 0.30.7, transformers 5.2.0
  - Converted model from HuggingFace to MLX 4-bit (7.6GB from 28GB) using `trust_remote_code=True`
  - Created startup script: ~/LJ-asi-mlx/run_vllm_mlx_iquest_coder.sh
  - Created documentation: IQUEST_CODER_VLLM_MLX_SETUP.md, IQUEST_CODER_VLLM_MLX_SUMMARY.md
  - Started server on port 8082 with reasoning parser (qwen3) and tool parser (qwen)
  - Server operational: http://localhost:8082/health returns healthy status
  - Tested completion endpoint successfully
- **Note**: Model uses custom iquestcoder architecture requiring trust_remote_code=True for conversion

## 2026-03-04 Session 25 - IQuest-Coder 8-bit Conversion
- **User**: Create 8-bit MLX version of IQuest-Coder-V1-14B-Thinking (~15GB)
- **Agent**:
  - Converted model to MLX 8-bit (14GB) using q_bits=8
  - Created separate startup scripts: run_iquest_4bit.sh (port 8082), run_iquest_8bit.sh (port 8083)
  - Updated documentation: IQUEST_CODER_VLLM_MLX_SETUP.md, created IQUEST_CODER_QUICKSTART.md
  - Both models now available:
    - 4-bit: 7.6GB, port 8082, good quality, ~10GB RAM
    - 8-bit: 14GB, port 8083, better quality, ~17GB RAM

## 2026-03-03 Session 23 - vLLM-MLX vs vLLM-Metal Analysis for IQuest-Coder-V1-14B-Thinking
- **User**: Explore repos in ~/LJ-asi-mlx/ to serve IQuest-Coder-V1-14B-Thinking model (14B, reasoning + tool calling). Model should be downloaded in MLX "tensor" format to ~/LJ-asi-mlx/models/. Create plan for serving on macbook2.
- **Agent**:
  - Read documentation for vllm-metal and vllm-mlx
  - vllm-metal: Plugin for vLLM enabling MLX backend on Apple Silicon. Installs via curl install.sh to ~/.venv-vllm-metal. Uses vLLM core + MLX compute.
  - vllm-mlx: Standalone vLLM-like implementation using pure MLX. Installs via uv/pip. Supports OpenAI + Anthropic APIs, multimodal (text/image/video/audio), reasoning parsers, tool calling, embeddings.
  - Both support required parsers: `--reasoning-parser qwen3` (extracts `</think>...
2026-03-26: User asked to rerun the old generated-data forced-context Qwen3.5-35B-A3B benchmark on macbook2 using the current llama.cpp wrapper and `Qwen3.5-35B-A3B-UD-Q8_K_XL.gguf`; I started the wrapper on 8081, reran the full none/small/mid/long/longlong matrix, compared it against the 2026-03-01 baseline, and confirmed the wrapper stayed stable with zero crashes.
2026-03-26: User asked to fold the refreshed Qwen 35B rerun into the existing results markdown; I appended a new 2026-03-26 rerun section with the current wrapper configuration, refreshed summary tables, and old-vs-new deltas.
2026-03-26: User asked to tighten the older March 1 labels too; I split the old summary into the actual 6-thread forced-context matrix plus the smaller 1-thread legacy subset so the labels now match the underlying raw files.
2026-03-26: User asked to benchmark `Nemotron-Cascade-2-30B-A3B.Q6_K.gguf` with the same none/small/mid/long/longlong forced-context matrix used for the recent Qwen rerun, while taking model-specific sampling from the Hugging Face card; I built a Nemotron wrapper from the Qwen non-model settings, extended the benchmark harness to support assistant-prefill for the thinking-off path, verified `chat template, thinking = 0` in the server log, and ran the full thinking-off matrix.
2026-03-26: User added a follow-up to rerun Nemotron with thinking ON and verify that state in the logs; I started a separate thinking-on wrapper, confirmed `chat template, thinking = 1` in the llama-server log and `reasoning_content` in a sanity response, reran the full matrix, and found the thinking-on path faster than the forced thinking-off path across all measured long-context bands.
2026-03-27: User asked to fold the Nemotron speed results into a higher-level comparison against the refreshed Qwen rerun, record the exact llama-server parameters, move future raw outputs under `runs/`, and then benchmark Nemotron on the same 92-problem LiveCodeBench subset as the incumbent Qwen. I added a cross-model context comparison doc, created a Nemotron LiveCodeBench launcher and model alias, hit an impractical first attempt at `max_tokens=100000`, replanned to a `16384` cap for the thinking-mode run, finished the full subset with `thinking = 1` confirmed in the server log, and recorded that Nemotron tied Qwen exactly at `0.7717` overall while running about `5.74x` slower.
2026-03-27: User asked whether thinking was to blame for Nemotron’s LCB runtime and asked for reasoning-budget investigation plus new `10K` follow-up runs. I verified the incumbent Qwen recheck really used `max_tokens=10000`, inspected the local llama.cpp reasoning-budget implementation, proved the forced budget message works on Nemotron, ran a `thinking on / 10K total / 4K budget` variant and a `thinking off / 10K total` control, and documented that bounded thinking raised Nemotron to `0.8152` in `8146s` while thinking OFF fell to `0.5000` in `1580s`.
2026-03-27: User asked to port the Nemotron context and LiveCodeBench workflow from macbook2 to gigul2 using the newly rebuilt ROCm llama-server and the local `Nemotron-Cascade-2-30B-A3B-IQ4_XS.gguf`; I added a gigul2 context-suite launcher, a gigul2 LiveCodeBench launcher with the requested `5000 / 10000` reasoning budget split, registered a new IQ4_XS LiveCodeBench alias, sanity-checked both thinking modes on the 7900 XTX, and launched the full suite under `runs/nemotron_gigul2_suite_20260327_221821/`.
2026-03-27: User asked for the finished gigul2 context readout and a comparison against the best current `Qwen3.5-35B-A3B` baseline; I extracted the completed OFF/ON context medians from `suite.log`, confirmed the only clean checked-in Qwen baseline is the refreshed macbook2 rerun in `runs/20260326_162504`, and wrote a new gigul2 Nemotron context report with explicit caveats and side-by-side tables.
2026-03-27: User then asked specifically for the prior gigul2 `Qwen3.5` baseline on the same hardware; I found the older same-box raw results in `benchmark_results_qwen35-35b-a3b-q4km_2026-02-27/` via `MEMORY.md`, recomputed the comparison against the current Nemotron gigul2 run, and corrected the report and repo notes to use the proper same-hardware baseline.
2026-03-28: User asked for the same-box LiveCodeBench write-up too; I located the nested score files in the local Qwen incumbent run, compared them against the completed Nemotron OFF and `5000 / 10000` budgeted-thinking suite outputs on gigul2, and wrote a dedicated report showing budgeted Nemotron beating Qwen `76 / 92` to `71 / 92` while OFF was faster but much weaker.
2026-03-28: User asked to investigate `JANGQ-AI/MiniMax-M2.5-JANG_2L` on macbook2 without re-downloading the 63 GB cache, figure out whether it needs a modified MLX runtime, and run the official example. I confirmed the existing `torch313` venv already had a working `jang` + `mlx` + `mlx-lm` stack, reused the cached snapshot path directly in offline mode, ran the example successfully, measured about `20-31s` cold load, about `5.9s` warm TTFT, about `0.5 tok/s` steady decode, and documented that the model fits in memory but is too slow to be attractive interactively on this hardware.
2026-03-28: User asked to rerun the macbook2 Metal context and LiveCodeBench Nemotron benchmarks with `Nemotron-Cascade-2-30B-A3B-Q8_0.gguf`, `ctx-size 1048576`, `n-predict 16384`, and an `8192` reasoning budget; I built repo-local `runs/` launchers around the requested wrapper settings, completed the full context matrix, patched the local `LiveCodeBench` model registry to add the missing `Nemotron-Cascade-2-30B-A3B-Q8` alias after an initial `KeyError`, reran only the LCB phase, and recorded that Q8 matched the best earlier Nemotron overall score (`0.8152`, `75/92`) but was slower (`12252s`).
2026-06-13: Added a public-safe local-LLM benchmark narrative in README.md, added six selected projects to the personal site page, and documented pending publication plus a manifest-first LJ-wiki audit.
