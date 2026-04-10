# LEARNINGS - SGLang HIP ROCm 7.1.1 GLM-4.7-Flash Project

## Purpose
Track friction points, root causes, and fixes to build toward autonomous operation.

## Git Worktree Setup
- **Date**: 2026-02-10
- **Learning**: Set up git worktree to have both `main` and `rocm-7900xtx-sgl-kernel` branches checked out simultaneously
  - `sglang-src/` - main branch (commit 835396fb3)
  - `sglang-rocm-branch/` - rocm-7900xtx-sgl-kernel branch (commit 0e1185513)
  - This allows comparing implementations and testing both versions without switching branches

## Benchmark Reporting Baselines (2026-03-27)
- **Date**: 2026-03-27
- **Learning**: There is no newer gigul2 `Qwen3.5-35B-A3B` forced-context suite checked into this repo than the refreshed macbook2 wrapper rerun in `runs/20260326_162504`.
- **Signpost**: When comparing a new gigul2 context suite against `Qwen3.5-35B-A3B`, use that macbook2 rerun as the current checked-in baseline and state the cross-machine and cross-quant caveat explicitly instead of implying a same-box comparison.

## Baseline Discovery Corrections (2026-03-27)
- **Date**: 2026-03-27
- **Learning**: The repo also contains an older but valid same-hardware gigul2 `Qwen3.5-35B-A3B` forced-context run in `benchmark_results_qwen35-35b-a3b-q4km_2026-02-27/`, even though the dedicated markdown reports emphasize the newer macbook2 rerun.
- **Signpost**: When asked for a same-box comparison, search raw result directories and `MEMORY.md`, not just the dedicated summary markdown files. The gigul2 Qwen baseline was discoverable there and should be preferred over a cross-machine macbook2 baseline.

## LiveCodeBench Artifact Layout (2026-03-28)
- **Date**: 2026-03-28
- **Learning**: The local Qwen LiveCodeBench incumbent stores its score files one level deeper under `Qwen3.5-35B-A3B-IQ4_subset/Qwen3.5-35B-A3B-IQ4/`, while the newer Nemotron suite writes score files directly under each run's model directory.
- **Signpost**: When comparing local LiveCodeBench runs, inspect the actual directory tree before assuming score files live directly under the run root. The Qwen incumbent needed a deeper lookup than the Nemotron suite.

## Startup Issues Encountered
- **Date**: 2026-02-10
- **Issue**: OOM during model loading with rocm branch + AWQ quantization
  - Error: "OutOfMemoryError: Tried to allocate 768.00 MiB" during weight initialization
  - Model tries to allocate ~23GB during loading, exceeds 24GB GPU capacity
  - Reducing mem-fraction-static (0.85 → 0.70 → 0.60) doesn't help - issue is model weights, not KV cache
  - Previous successful runs (Jan 29) used tiny context (2048 tokens), not useful for testing
- **Root cause**: AWQ quantization on rocm branch may have compatibility issues with this MoE model
- **Tried solutions (all failed)**:
  1. ✗ Main branch (sglang-src) - same OOM
  2. ✗ Reduced mem-fraction-static (0.85 → 0.70) - doesn't affect model loading
  3. ✗ CPU offloading (--cpu-offload-gb 4) - offloading happens after loading
- **Conclusion**: Finding compatible GLM-4.7-Flash quantization for single 24GB GPU is challenging

## Model Compatibility Matrix (2026-02-10)

| Model | Size | Quantization | Status | Issue |
|-------|------|--------------|--------|-------|
| **QuantTrio/GLM-4.7-Flash-AWQ** | 19GB | AWQ (group_size 128) | ❌ OOM | Designed for 2 GPUs, ~23GB VRAM needed |
| **cyankiwi/GLM-4.7-Flash-AWQ-4bit** | 17.2GB | compressed-tensors | ❌ Error | `ReplicatedLinear` incompatibility with sglang |
| **TheHouseOfTheDude/GLM-4.7-Flash_AWQ** | ? | AWQ (group_size 32, MoE-optimized) | ⚠️  Untested | Documentation shows 2 GPU setup |
| **Intel/GLM-4.7-Flash-int4-AutoRound** | ~1B params | INT4 AutoRound | ⚠️  Untested | HIP ROCm 7.1.1 compatibility unknown, Intel-specific |
| **QuantTrio (tiny context)** | 19GB | AWQ | ✅ Works | Only with max-total-tokens=2048 |

## Testing Context
- **GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
- **Port for testing**: 8081
- **Model (sglang)**: models--QuantTrio--GLM-4.7-Flash-AWQ
- **Model (llama.cpp)**: GLM-4.7-Flash-UD-Q5_K_XL.gguf (5-bit quant, better quality, reduced context from 200K to 95K)
- **Performance baseline (llama.cpp)**: ~10 tokens/sec with long context (potentially slow)
- **HF Token**: Configured for authenticated downloads (avoids rate limiting)

## Project Goals
- Make sglang run fast on AMD GPU 7900xtx
- Leverage prompt prefix caching in sglang
- Compare with llama.cpp which has caching/hashing capabilities

## Benchmark Infrastructure Created
- **Date**: 2026-02-10
- Created `run_sglang_8081.sh` - startup script for sglang on port 8081 (rocm branch)
- Created `bench_comprehensive.py` - comprehensive benchmark capturing:
  - **Throughput**: chars/sec via streaming response
  - **Latency**: TTFT (time to first token)
  - **Cache hit rates**: queried from /metrics endpoint (`sglang:cache_hit_rate`)
  - **Memory usage**: GPU VRAM via rocm-smi
  - **Token stats**: cached_tokens, prompt_tokens, generation_tokens from Prometheus
- Tests multiple prompt lengths: 100, 1000, 5000, 10000, 20000 chars
- Outputs to JSONL for analysis
- **SGLang Metrics Endpoint**: `/metrics` (Prometheus format, always accessible)

## Usage
```bash
# Start sglang server (rocm branch) on port 8081
./run_sglang_8081.sh

# Run comprehensive benchmark
python3 bench_comprehensive.py --base http://192.168.1.251:8081 --runs 3

# Custom prompt lengths
python3 bench_comprehensive.py --prompt-lengths 500,2000,10000 --max-tokens 4096
```

## DIY Quantization Attempts (2026-02-10)
- **Date**: 2026-02-10
- **Attempt 1: AutoAWQ**
  - Error: `TypeError: glm4_moe_lite isn't supported yet.`
  - Root cause: AutoAWQ doesn't support GLM-4 MoE Lite architecture
  - Additionally: AutoAWQ is deprecated, moved to vLLM's llm-compressor
  - Conclusion: Need to use llm-compressor or AMD Quark instead

- **Attempt 2: llm-compressor (from git)**
  - llm-compressor has glm4_moe support (issue #1703 resolved Aug 2025)
  - Error: Installation downgraded PyTorch from ROCm 2.11.0 to CUDA 2.9.1
  - Error: ModuleNotFoundError with transformers/torchvision compatibility
  - Root cause: Version conflicts between llm-compressor and HIP ROCm 7.1.1 torch

- **Attempt 3: GPTQModel**
  - GPTQModel 5.6.12 has GLM-4 patches and MoE support
  - Error: Installation replaced HIP ROCm 7.1.1 torch with CUDA torch
  - Result: venv now detects old NVIDIA Quadro K620 instead of AMD 7900 XTX
  - Root cause: All quantization libraries have hard dependencies on CUDA torch

**Critical Learning**: Quantization tools (AutoAWQ, llm-compressor, GPTQModel) all have hard CUDA dependencies that break HIP ROCm 7.1.1 venv. Need isolated approach or pre-quantized models.

## vLLM Build Process (2026-02-10)
- **Date**: 2026-02-10
- **Issue**: Triton for HIP ROCm 7.1.1 build extremely slow (~20+ minutes)
- **Root cause**: Downloads and extracts massive 3.6GB+ LLVM toolchain to `~/.triton/llvm/`
  - LLVM download/extraction happens silently (no stdout output)
  - Python 3.13's new tar security checks add overhead
  - Creates illusion that build is frozen, but it's actively working
- **Monitoring tips**:
  - Check network connections: `ss -tnp | grep python3`
  - Check cache directory: `du -sh ~/.triton/llvm/`
  - Check open files: `lsof -p <pid> | grep "4w"`
  - Check process CPU time: `ps -p <pid> -o etime,cputime,%cpu`
- **Expected timeline**:
  - LLVM download/extract: 15-20 minutes (silent, no log output)
  - Triton compilation: 5-10 minutes (verbose output)
  - vLLM build: 5-10 minutes
  - Total: ~30-40 minutes from fresh start
- **Learning**: vLLM documentation understates build time (says 5-10 min, actually 30-40 min)

## llama.cpp Baseline Results (2026-02-10) - COMPLETED
- **Date**: 2026-02-10
- **Model**: GLM-4.7-Flash-UD-Q5_K_XL.gguf (95K context)

### Empty Context Results (UNREALISTIC):
  - Prompt 100 chars: TTFT=0.033s (warm), Throughput=404 chars/s (~101 tok/s)
  - Prompt 1000 chars: TTFT=0.037s (warm), Throughput=448 chars/s (~112 tok/s)
  - Prompt 5000 chars: TTFT=0.031s (warm), Throughput=374 chars/s (~94 tok/s)
  - First run slower (cold cache): TTFT=0.19-0.64s
  - **CRITICAL LIMITATION**: Tests run with EMPTY context (0-5K tokens)

### Realistic Long-Context Results (40K context prefill):
  - **40K context + 10K prompt (50K total)**:
    - TTFT: **79.998s** (2600x slower than empty!)
    - Throughput: **6.9 tok/s** (93% degradation from empty)
    - First prefill: 125s (cold), subsequent: 0.35s (warm, 357x faster)
  - **40K context + 15K prompt (55K total)**:
    - TTFT: **127.016s** (4200x slower than empty!)
    - Throughput: **4.4 tok/s** (96% degradation from empty)
    - Context size impact: 37% slower with just 5K more tokens

### Key Insights:
  - **Caching works excellently**: 125s → 0.35s prefill (357x speedup)
  - **O(n²) attention kills performance**: 94-112 tok/s → 4-7 tok/s with realistic context
  - **TTFT is catastrophic**: 80-127 seconds due to GLM-4.7-Flash reasoning tokens
  - **Memory bandwidth limited**: Performance degrades 37% with 5K more context
  - **Production reality**: ~5-7 tok/s for 50K context scenarios (vs 100+ tok/s empty)

### Comparison:
| Scenario | Context | TTFT | Throughput | Use Case |
|----------|---------|------|------------|----------|
| Empty | 0-5K | 0.03s | 94-112 tok/s | Benchmarks only |
| Realistic | 50K | 80s | 6.9 tok/s | Production |
| Realistic | 55K | 127s | 4.4 tok/s | Production |

- **Context**: User's goal is to test vLLM/sglang for better concurrent request handling and radix caching vs llama.cpp
- **Baseline established**: True performance is 4-7 tok/s for realistic long-context workloads

## vLLM GGUF Support Issues (2026-02-10)
- **Date**: 2026-02-10
- **Issue**: vLLM doesn't support deepseek2 architecture in GGUF files
- **Error**: `ValueError: GGUF model with architecture deepseek2 is not supported yet.`
- **Root cause**: GLM-4.7-Flash uses deepseek2 MoE architecture, which isn't in vLLM's GGUF loader yet
- **Build status**: vLLM 0.15.2rc1 built successfully from source for gfx1100
- **Platform workaround**: Had to disable CUDA detection in vLLM source code (dual-GPU system issue)
- **Conclusion**: vLLM cannot load this specific GGUF model

## Final Status Summary
- **SGLang**: ❌ Blocked by ROCm 7.1.1 symbol incompatibility
- **vLLM**: ❌ GGUF deepseek2 architecture not supported
- **llama.cpp**: ✅ Working excellently (94-112 tok/s warm, good caching)

## Build Timeline Summary
- Triton for HIP ROCm 7.1.1: ~27 min (LLVM download 16 min + compilation 11 min)
- vLLM from source: ~25 min (dependencies 2 min + CMake 5 min + compilation 18 min)
- Total time invested: ~4 hours (including all troubleshooting)

## HIP ROCm 7.1.1 vs Vulkan Backend (2026-02-11) - CRITICAL FINDING

**On identical hardware (7900 XTX), HIP ROCm 7.1.1 is 2.6-3.7x faster than Vulkan.**

| Context | HIP ROCm 7.1.1 tok/s | Vulkan tok/s | Speedup | HIP ROCm 7.1.1 TTFT | Vulkan TTFT |
|---------|-----------|-------------|---------|-----------|-------------|
| 20K | 39.2 | 15.3 | 2.6x | 8.8s | 29.2s |
| 25K | 29.2 | 10.2 | 2.9x | 14.9s | 51.4s |
| 50K | 21.8 | 6.9 | 3.2x | 20.6s | 80.0s |
| 55K | 16.2 | 4.4 | 3.7x | 32.5s | 126.3s |

**Key insights**:
1. HIP ROCm 7.1.1 advantage grows with context size (Vulkan dispatch overhead compounds)
2. HIP ROCm 7.1.1 makes 50-55K context genuinely interactive (21-33s TTFT)
3. Vulkan was the bottleneck, not the hardware - consuming 60-75% of potential performance
4. Cold prefill 3.9x faster on HIP ROCm 7.1.1 (32s vs 125s for 40K tokens)
5. **Always use HIP ROCm 7.1.1 backend on AMD GPUs for llama.cpp** - Vulkan should only be fallback

## vLLM 0.16.0rc2 Build for ROCm 7.1.1 (2026-02-11) - SUCCESS

### Build Details
- **Source**: vllm-src/ at commit bcd65c1f6 (v0.16.0rc1-184)
- **Venv**: ~/python3-venv/vllm-rocm/ (Python 3.13.7)
- **PyTorch**: 2.10.0+rocm7.1 (from download.pytorch.org/whl/rocm7.1/)
- **Extensions**: _C.abi3.so, _moe_C.abi3.so, _rocm_C.abi3.so all built and loadable
- **GGUF deepseek2**: Now supported (fixed in commit 7f0be2aa2)

### Build Issues and Fixes
1. **amdsmi version mismatch**: pip's amdsmi 6.4.3 has `amdsmi_get_power_info_v2` not in ROCm 7.1.1's libamd_smi.so → Install from /opt/rocm-7.1.1/share/amd_smi (v26.2.0)
2. **CMake too old**: System cmake 3.22.1 < 3.26 required → Put venv bin on PATH (cmake 4.2.1)
3. **Missing cmake packages**: rocrand, hiprand, hipfft, rocsolver, rccl, hsa-runtime64 missing from ROCm 7.1.1 → Symlink cmake configs AND libraries from ROCm 7.2.0
4. **Library version suffix mismatch**: ROCm 7.2.0 cmake expects .70200 suffix, 7.1.1 has .70101 → Create compatibility symlinks
5. **Dual-GPU platform conflict**: Both Quadro K620 (NVIDIA) and 7900 XTX (AMD) detected → Patched vllm/platforms/__init__.py to prefer ROCm when torch.version.hip is set

### Critical Learning: Dual-GPU Platform Detection
Systems with both NVIDIA and AMD GPUs trigger `RuntimeError: Only one platform plugin can be activated, but got: ['rocm', 'cuda']`. The fix is to check `torch.version.hip` vs `torch.version.cuda` and prefer the platform matching the PyTorch build.

### Critical Learning: ROCm 7.1.1 Package Gaps
ROCm 7.1.1 is missing many cmake config files despite having the -dev packages installed. Symlinking from ROCm 7.2.0 works because the API is compatible, but library version suffixes differ (.70200 vs .70101) and need additional compatibility symlinks.

## vLLM GGUF Support SUCCESS (2026-02-14) - GLM-4.7-Flash Running!

### Achievement
- **vLLM successfully loads and runs GLM-4.7-Flash GGUF on ROCm 7.1.1**
- Model architecture: DeepseekV2ForCausalLM (deepseek2 in GGUF)
- Attention: Triton MLA backend (no flash_attn on ROCm)
- OpenAI-compatible API on port 8081

## Nemotron Cascade 2 Benchmarking (2026-03-26)
- **Issue**: Benchmarking a thinking-capable model can silently measure the wrong mode if server flags, template kwargs, and assistant-prefill are not all aligned.
- **Root cause**: For llama.cpp chat templates, `--reasoning on/off`, `chat_template_kwargs.enable_thinking`, and assistant-prefill each influence whether the template runs in thinking mode. Assistant-prefill also forces reasoning parsing off for that request path.
- **Reliable verification**:
  - Check the llama-server startup log for `srv init: init: chat template, thinking = 0/1`
  - Send a tiny chat completion and confirm whether `reasoning_content` is present when thinking is expected to be on
- **Nemotron-specific result**:
  - Thinking OFF run used `--reasoning-format none --reasoning off` plus assistant-prefill `<think></think>` with `chat_template_kwargs={"enable_thinking":false}`
  - Thinking ON run used `--reasoning-format deepseek --reasoning on` with no assistant-prefill
  - On macbook2 Metal, the thinking-on path was faster than the forced thinking-off path across every measured long-context band from 15K through 115K total context, and also improved none-context throughput

### Key Discoveries
1. **deepseek2 GGUF support**: Working in vLLM 0.16.0rc2 (commit bcd65c1f6)
2. **MLA parameters**: Must include kv_lora_rank, q_lora_rank, qk_nope_head_dim, v_head_dim in config.json
3. **MoE parameters**: Must include n_routed_experts, n_shared_experts, num_experts_per_tok, moe_intermediate_size
4. **Transformers 5.1.0**: Required (has Glm4MoeLiteConfig and better GGUF support)
5. **Tokenizer issue**: Generated text garbled - needs investigation

### Startup Command
```bash
source /home/ljubomir/python3-venv/vllm-rocm/bin/activate
PYTORCH_ROCM_ARCH=gfx1100 HIP_VISIBLE_DEVICES=0 python3 -m vllm.entrypoints.openai.api_server \
  --model /home/ljubomir/rocm-glm-4.7-flash/vllm-model/GLM-4.7-Flash-UD-Q4_K_XL.gguf \
  --hf-config-path /home/ljubomir/rocm-glm-4.7-flash/vllm-model \
  --tokenizer /home/ljubomir/rocm-glm-4.7-flash/vllm-model \
  --port 8081 \
  --dtype half \
  --max-model-len 4096
```

### Known Issues
- **Garbled output**: Tokenizer not properly decoding (GGUF tokenizer extraction incomplete)
- **flash_attn**: Not available on ROCm, using PyTorch SDPA fallback (slower)
- **Limited context**: 4096 max (needs investigation for longer contexts)

### Next Steps
- ~~Fix tokenizer/garbled output issue~~ → **Investigated, root causes identified (see below)**

## vLLM GLM-4.7-Flash Comprehensive Investigation (2026-02-14) - ROOT CAUSES IDENTIFIED

### Investigation Summary
After extensive testing of multiple model formats and configurations, **vLLM on ROCm 7.1.1 has fundamental compatibility issues with GLM-4.7-Flash** that make it unusable for production use.

### Root Cause Analysis

| Attempt | Model Format | Result | Root Cause |
|---------|--------------|--------|-------------|
| **GGUF** | GLM-4.7-Flash-UD-Q4_K_XL.gguf | ❌ Garbled output | GGUF loader maps deepseek2→DeepseekV2ForCausalLM, but GLM-4.7-Flash is actually Glm4MoeLiteForCausalLM. Tensor names/structures incompatible. |
| **Unsloth FP8** | unsloth/GLM-4.7-Flash-FP8-Dynamic | ❌ NotImplementedError | "No FP8 MoE backend supports the deployment configuration" - FP8 MoE not supported on ROCm |
| **cyankiwi AWQ** | cyankiwi/GLM-4.7-Flash-AWQ-4bit | ❌ ValueError | compressed-tensors WNA16 format not supported on ROCm (group_size 32, needs 128) |
| **Original HF** | zai-org/GLM-4.7-Flash | ❌ OOM | Unquantized BF16 model ~60GB, exceeds 24GB GPU |
| **QuantTrio AWQ** | QuantTrio/GLM-4.7-Flash-AWQ | ❌ Untested | Designed for 2 GPUs, ~23GB VRAM minimum |

### Detailed Technical Issues

#### 1. GGUF Architecture Mismatch
- **Symptom**: Text output like "by to from by iÃ§in to unless to to- * to-??"
- **Cause**: GGUF file reports `general.architecture = deepseek2`, vLLM's GGUF loader maps this to `DeepseekV2ForCausalLM`
- **Reality**: GLM-4.7-Flash uses `Glm4MoeLiteForCausalLM` architecture
- **Impact**: Tensor shapes and names don't match between architectures, causing incorrect weight loading
- **Fix attempted**: Updated config.json with `Glm4MoeLiteForCausalLM` architecture and correct MLA/MoE params
- **Result**: Still garbled - deep architectural incompatibility between deepseek2 GGUF format and Glm4MoeLite

#### 2. FP8 MoE Not Supported on ROCm
```python
# From vllm-src/vllm/model_executor/layers/fused_moe/oracle/fp8.py:347
if current_platform.is_cuda() or current_platform.is_rocm():
    raise NotImplementedError(
        "No FP8 MoE backend supports the deployment configuration."
    )
```
- **Why**: FP8 MoE kernels (Marlin, DeepGEMM, FlashInfer, AITER) are CUDA-only
- **AITER**: AMD's Triton-based MoE kernel, but only for specific FP8 formats
- **ROCm limitation**: No FP8 MoE support in current vLLM for AMD GPUs

#### 3. compressed-tensors WNA16 Format Incompatibility
```
ValueError: Failed to find a kernel that can implement the WNA16 linear layer.
Reasons:
- ConchLinearKernel: Group size (32) not supported (only -1, 128)
- ExllamaLinearKernel: Only supports float16 activations
```
- **cyankiwi model**: Uses group_size=32 compressed-tensors quantization
- **ROCm support**: WNA16 kernels not available or limited

#### 4. Unquantized Model Too Large
- **Model size**: ~60GB (BF16 weights)
- **GPU VRAM**: 24GB (7900 XTX)
- **Result**: `torch.OutOfMemoryError: Tried to allocate 768.00 MiB. GPU 0 has a total capacity of 23.98 GiB of which 378.00 MiB is free.`

### HF Transformers Investigation (2026-02-14)

#### Recent GLM-4.7-Flash Support Added
- **Commit**: `76732b4e71 [GLM-4.7] GLM-Lite Support (#43031)` (Jan 13, 2026)
- **Added**: `Glm4MoeLiteForCausalLM`, `Glm4MoeLiteConfig` to transformers
- **Recent fixes**:
  - `e5fa6fee54`: Fix gradient reduction for k_rot tensor
  - `2ac7fed2f3`: Fix tensor parallel configuration
- **Status**: All fixes present in transformers 5.1.0 (our venv has these)

#### Correct GLM-4.7-Flash Configuration
```python
# From AutoConfig.from_pretrained("zai-org/GLM-4.7-Flash")
architectures: ['Glm4MoeLiteForCausalLM']
model_type: glm4_moe_lite
hidden_size: 2048
num_hidden_layers: 47
num_attention_heads: 20
num_key_value_heads: 20  # NOT 1!
kv_lora_rank: 512
q_lora_rank: 768
qk_nope_head_dim: 192
qk_rope_head_dim: 64
v_head_dim: 256
n_routed_experts: 64
n_shared_experts: 1
num_experts_per_tok: 4
moe_intermediate_size: 1536
vocab_size: 154880
```

### vLLM ROCm Limitations Summary

| Feature | CUDA Support | ROCm Support | Impact |
|---------|--------------|--------------|---------|
| FP8 MoE (Marlin) | ✅ | ❌ | Can't use Unsloth FP8 |
| FP8 MoE (DeepGEMM) | ✅ | ❌ | Can't use Unsloth FP8 |
| FP8 MoE (FlashInfer) | ✅ | ❌ | Can't use Unsloth FP8 |
| FP8 MoE (AITER) | ✅ | ⚠️ Limited | ROCm AITER only for specific formats |
| compressed-tensors WNA16 | ✅ | ❌ | Can't use cyankiwi AWQ |
| MLA Triton backend | ✅ | ✅ | Working (used in GGUF attempt) |
| flash_attn | ✅ | ❌ | Using PyTorch SDPA fallback (slower) |

### Conclusion

**vLLM on ROCm 7.1.1 cannot serve GLM-4.7-Flash effectively.** The limitations are:

1. **GGUF format**: Architecture incompatibility (deepseek2 vs Glm4MoeLite) cannot be resolved via config changes
2. **FP8 quantization**: Not supported on ROCm (CUDA-only kernels)
3. **compressed-tensors**: Limited ROCm support (group size restrictions)
4. **Unquantized model**: Exceeds single 24GB GPU capacity

### Recommendation

**Use llama.cpp for GLM-4.7-Flash on ROCm 7.1.1.** It provides:
- ✅ Proper GGUF support with correct tokenizer
- ✅ Quantized models that fit in 24GB VRAM
- ✅ Excellent performance (~30 tok/s with proper context handling)
- ✅ Full 95K context support (Q5_K_XL)

### vLLM ROCm Development Priorities (for future)

To make vLLM viable for GLM-4.7-Flash on ROCm:
1. **Add ROCm FP8 MoE support** (AITER or new kernels)
2. **Fix GGUF deepseek2→Glm4MoeLite architecture mapping** or support proper Glm4MoeLite GGUF
3. **Expand compressed-tensors ROCm support** for more group sizes
4. **Enable flash_attn on ROCm** for faster MLA prefill

### Files Modified During Investigation
- `/home/ljubomir/rocm-glm-4.7-flash/vllm-model/config.json` - Attempted architecture fixes
- `/home/ljubomir/rocm-glm-4.7-flash/vllm-src/` - vLLM source (built from commit bcd65c1f6)
## 2026-02-14 Session 11 - Local cyankiwi Model Success but Output Issue
  - **User**: Asked about local cyankiwi GLM-4.7-Flash-AWQ-4bit model (http://huggingface.co/cyankiwi/GLM-4.7-Flash-AWQ-4bit)
  - **Agent**:
    - Checked local model directory - found 19GB of safetensors files
    - Model config shows `glm4_moe_lite` architecture (correct)
    - Model is CompressedTensorsWNA16 format, group_size=32
    - Started vLLM successfully with local model path
    - Model loads: 18GB, takes ~160 seconds
    - Triton MLA backend working (no flash_attn on ROCm)
    - **CRITICAL ISSUE**: Server responds but `content` field is `null` - model not generating text!
    - Using `--reasoning-parser glm45` causes empty output when model doesn't use that format
    - vLLM server fully operational but unusable for text generation

## Qwen3-Coder-Next MoE Offloading on 24GB VRAM (2026-02-15)

### Optimal Configuration
- **--n-cpu-moe 29**: First 29 layers' experts on CPU, last 19 layers' experts on GPU
- **--threads 20**: Dual Xeon benefits from more threads (40% speedup over 10 threads)
- **--flash-attn on**: rocWMMA fast attention enabled

### Results
- Prompt processing: 114 tok/s
- Generation: 13.58 tok/s
- Fits in 24GB VRAM

### Key Insights
1. **Reddit's n-cpu-moe 27 recommendation is for 32GB VRAM** (RTX 5090)
2. **24GB VRAM requires n-cpu-moe 29 minimum** - n-cpu-moe 28 OOMs
3. **Performance scales linearly with GPU experts**: Each layer adds ~0.3-0.5 tok/s
4. **CPU threads matter**: 20 threads provides 40% improvement over 10 threads
5. **Model is 80B parameters** despite being "Q5_K_XL" quantized

### Threshold Values
| n-cpu-moe | Status | Speed |
|-----------|--------|-------|
| 28 | OOM | N/A |
| 29 | ✅ Fits | 13.58 tok/s |
| 30+ | ✅ Fits | 12-13 tok/s |
| 48 | ✅ All CPU | 5.9 tok/s |

### Server Command Template
```bash
llama-server \
  --device ROCm0 \
  --gpu-layers all \
  --model ~/llama.cpp/models/UD-Q5_K_XL/Qwen3-Coder-Next-UD-Q5_K_XL-00001-of-00003.gguf \
  --threads 20 \
  --threads-batch 10 \
  --flash-attn on \
  --n-cpu-moe 29
```


## RPATH Fix for Renamed Build Directories (2026-02-15)

### Problem
When llama.cpp build directory is renamed after compilation, binaries fail with:
```
llama-server: error while loading shared libraries: libmtmd.so.0: cannot open shared object file
```

### Root Cause
Binaries have hardcoded `RUNPATH` pointing to build directory at compile time.

### Solution
Use `patchelf` to update RUNPATH to use `$ORIGIN` (relative path):

```bash
# Install patchelf if needed
sudo apt install patchelf

# Update RUNPATH for all binaries
for file in build-dir/bin/*; do
  patchelf --set-rpath "\$ORIGIN:/opt/rocm-7.1.1/lib" "$file"
done
```

### Script Created
`/data1/data/llama.cpp/fix_rpath_rocwmma.sh` - Automated fix with backup/restore

### Key Point
`$ORIGIN` expands to the directory containing the binary at runtime, making binaries portable regardless of directory name.

## MLX GLM-4.7-Flash Context Limit Bug (2026-02-16)

### Problem
GLM-4.7-Flash (MLX-8bit, `glm4_moe_lite` arch) crashes at ~15K-17K tokens on Apple MLX backend with:
```
AttributeError: 'list' object has no attribute 'swapaxes'
```

### Root Cause
Bug in the MLX implementation of the `glm4_moe_lite` attention mechanism. The model config says max_position_embeddings=202752 and memory (96GB) is ample, but the MLX kernel fails on longer sequences.

### Workarounds Found
- **Context length 32768 with `lms load`**: Works for sequences up to ~15K tokens
- **Context length 150000**: Causes instability even at 10K tokens (larger KV cache allocation destabilizes)
- **Multi-turn messages (two consecutive user msgs)**: Crashes the model. Use single combined user message instead.
- **Auto-reload**: `lms unload --all && lms load <model> --gpu max --context-length 32768 -y` recovers from crashes

### Key Learnings
1. LM Studio `lms` CLI enables automated crash recovery: `lms unload --all` then `lms load <path> --gpu max -c <ctx> --identifier <id> -y`
2. `lms ps` shows loaded models with context length and status
3. The crash threshold is non-deterministic near the boundary (~15K-17K) - may work one run and crash the next
4. Loading with large context length (150K) vs small (32K) changes the crash threshold downward

## gfx1100 (7900 XTX) Support Deep Dive Across ML Frameworks (2026-02-18)

### ROCm 7.1.1 Constraint
- ROCm 7.2.0 requires Linux kernel upgrade beyond current 5.15.0-168-generic
- ROCm 7.1.1 runtime is functional; 7.2.0 packages installed for cmake symlinks only
- PyTorch 2.10.0+rocm7.1 works; venv at ~/python3-venv/vllm-rocm/

### SGLang gfx1100 Status
- **Explicitly supported**: `setup_rocm.py:77` lists gfx1100 in `supported_targets`
- **FP8 disabled**: `setup_rocm.py:85` - only gfx942/gfx950 (hardware limitation)
- **AITER auto-selected** as default attention backend for HIP
- **Build gotcha**: `3rdparty/amd/sgl-kernel/build_rocm.sh:6` defaults `AMDGPU_TARGET="gfx942;gfx950"` - must override to include gfx1100
- **Still blocked** by `hsa_amd_memory_get_preferred_copy_engine` symbol issue on ROCm 7.1.1

### vLLM gfx1100 Status
- **In CMake arch list**: `CMakeLists.txt:40`
- **Device ID mapped**: `platforms/rocm.py:61` → `"0x744c": "AMD_Radeon_RX7900XTX"`
- **CRITICAL**: AITER library gated behind `on_gfx9()` in `_aiter_ops.py:36-56` - blocks fused MOE, RMSNorm, FP8 linear, all AITER MLA backends
- **Custom paged attention restricted** for gfx11: head_size=128 only, block_size=16, gqa_ratio 3-16
- **Flash Attention Triton for RDNA**: exists at `platforms/rocm.py:197-215`, needs `FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE` env var + flash_attn with Triton AMD backend
- **FP8 format difference**: gfx1100 uses e4m3fn (not fnuz like MI300)
- **No CI testing on gfx1100** - all tests on MI325 (mi325_1 agent pool)
- **Default backend**: TRITON_ATTN (Triton Unified Attention) - functional but slower than AITER

### Transformers gfx1100 Status
- **SDPA works** on ROCm (default fallback, adequate for inference)
- **FA2**: ROCm supported (≥2.0.4) but Docker only builds gfx942
- **FA3**: Blocked by hardcoded `torch.cuda.get_device_capability()` check requiring compute cap ≥ 9.0
- **Eager attention** always works
- **No gfx1100 in any Docker/CI** configuration

### BarraCUDA Assessment
- Impressive 15K-line C99 CUDA→GFX11 compiler, produces working .hsaco ELFs
- **Not useful for ML framework porting**: handles simple CUDA C, not C++17 template metaprogramming
- Missing: compound assignment, const, multiple TUs, host code, runtime API
- Real blockers are architectural gatekeeping and missing implementations, not compilation
- Potentially useful as GFX11 ISA reference material

### Actionable Fix Paths (Priority Order)
1. **GGUF arch mapping in vLLM**: Map deepseek2→Glm4MoeLiteForCausalLM when config indicates it
2. **Relax AITER gfx9 gate**: Some AITER ops (Triton-based) may work on gfx11 - `_aiter_ops.py`
3. **Build flash_attn Triton AMD for gfx1100**: vLLM already has the code path
4. **Stick with llama.cpp**: Best current option for GLM-4.7-Flash (30+ tok/s with HIP ROCm 7.1.1)

## Session 17: LongCat-Flash-Lite 69B MLX Benchmarks (2026-02-26)

### mlx_lm.server model name must be exact path
- **Problem**: Using `--model default` in API requests causes mlx_lm.server to look up "default" on HuggingFace (404).
- **Fix**: Use the full model path from `/v1/models` response as the model name in requests. Unlike LM Studio/llama.cpp, mlx_lm has no "default_model" alias for requests.

### 100K context crashes Metal GPU at 5.5-bit quantization
- **Problem**: 100K prefill with 5.5-bit LongCat (~50GB) causes `Metal Command buffer execution failed: Internal Error (0000000e)` at ~45K tokens processed.
- **Root cause**: GPU memory exhaustion — model weights + KV cache exceeds 92GB unified memory.
- **Fix**: Use 4-bit (mxfp4) quantization (~36GB) for 100K+ context, or cap context at ~55K with 5.5-bit.

### MLA attention scales better than standard MoE attention at long context
- **Finding**: 69B LongCat-Flash-Lite at 50K context achieves 3.5 tok/s on mlx_lm, while 9B GLM-4.7-Flash on vLLM-MLX only achieves 2.7 tok/s at the same context. Multi-Latent Attention (MLA) compresses KV cache, reducing memory bandwidth pressure at long contexts.

### Qwen3.5-122B-A10B Q3_K_XL on macbook2 Metal — practical context limit ~55K
- **Finding**: 122B MoE model (Q3_K_XL, ~51GB) on M2 Max 96GB achieves ~15 tok/s baseline (no context), degrades to 3.2 tok/s at 55K total context. Prompt processing speed is 69.5 tok/s.
- **Problem**: 100K context crashes Metal with `command buffer failed with status 5` at ~58K tokens. Same error pattern as LongCat 5.5-bit crash, confirming ~55K as the practical context ceiling for ~50GB models on 96GB M2 Max with q8_0 KV cache.
- **Potential fix**: Use q4_0 KV cache types instead of q8_0 to halve KV memory, or reduce ctx-size to 65536.

- `~/llama.cpp/run_llama_qwen_wrapper_macbook2.sh` currently defines both `SERVER_ARGS` and `SERVER_ARGS_DRAFT`, but the live wrapper path still launches `SERVER_ARGS`. When rechecking Qwen 35B performance on macbook2, treat it as a non-speculative baseline unless the script is explicitly switched.
- For `rocm-glm-4.7-flash`, write raw benchmark outputs under the repo-local `runs/` directory rather than `~/tmp/...` so later comparison docs can link to stable paths.
- The local Nemotron thinking-mode LiveCodeBench path was impractical with `max_tokens=100000`: the first window reached only `1/36` problems after `21m19s`, with problem 2 still open. For local thinking-model LCB reruns, cap both the request and server at `16384` unless there is evidence the model needs more.
- The final local Qwen3.5-35B-A3B LiveCodeBench incumbent used `max_tokens=10000`, not `4000`. When comparing later runs against it, separate the older `4000` matrix result from the final `0.7717` recheck.
- On local llama.cpp LiveCodeBench runs, the reasoning-budget feature can materially improve a thinking model rather than just limiting it. Nemotron improved from `0.7717` in `17148s` with unbounded `16384` thinking to `0.8152` in `8146s` with a `4096` reasoning budget inside a `10000` total cap.
- On the 7900 XTX, do not launch multiple full Nemotron llama-server sanity runs in parallel and then trust the first OOM at face value. A concurrent second launch can consume the same VRAM and create a false `cudaMalloc failed: out of memory` during model load even though a single-server launch with the same flags fits and serves requests correctly.
- `JANGQ-AI/MiniMax-M2.5-JANG_2L` did not need any extra bespoke MLX checkout on macbook2 once `jang 2.2.0`, `mlx 0.30.6`, and `mlx-lm 0.30.7` were installed in the venv. Loading the cached local snapshot path directly was enough.
- MiniMax JANG_2L fits on macbook2 at roughly `67.9 GB` peak memory, but speed is poor on this hardware: warm TTFT was about `5.9s` and steady decode only about `0.5 tok/s` even with the model-card sampler (`temp=1.0`, `top_p=0.95`, `top_k=40`).
- The local `LiveCodeBench` checkout keeps its own `LanguageModelStore`. Adding a new local llama.cpp alias in a launcher script is not enough; the alias must also be registered in `LiveCodeBench/lcb_runner/lm_styles.py` or the run will fail immediately with `KeyError: <model-name>`.
- On macbook2 Metal, `Nemotron-Cascade-2-30B-A3B-Q8_0` with thinking `ON`, `16384` total cap, and `8192` reasoning budget matched the best earlier Nemotron overall LCB score (`0.8152`) but took much longer (`12252s` vs `8146s`). Q8 bought harder-problem accuracy, not a better overall operating point.
- On the forced-context matrix, `Nemotron-Cascade-2-30B-A3B-Q8_0` did not produce a speed win over the earlier Q6 thinking-on run on macbook2 Metal. If Q8 is chosen locally, the justification has to be quality, not throughput.
