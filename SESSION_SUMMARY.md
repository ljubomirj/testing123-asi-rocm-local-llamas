# Session Summary - GLM-4.7-Flash with SGLang on AMD 7900 XTX

## Goal
Run GLM-4.7-Flash with SGLang on AMD 7900 XTX (24GB VRAM) for faster inference with prefix caching vs llama.cpp baseline.

## What We Tried

### 1. Pre-Quantized Models
| Model | Size | Issue |
|-------|------|-------|
| QuantTrio AWQ | 19GB | Needs ~31GB VRAM (designed for 2 GPUs) |
| cyankiwi AWQ | 17GB | Uses compressed-tensors format (incompatible with sglang) |
| TheHouseOfTheDude AWQ | ? | Documentation suggests 2 GPU setup |

**Result**: ❌ No compatible pre-quantized models found for single 24GB GPU

### 2. DIY Quantization Attempts

#### AutoAWQ
- **Error**: `TypeError: glm4_moe_lite isn't supported yet`
- **Issue**: Doesn't support GLM-4's custom MoE architecture
- **Additional**: Deprecated, moved to llm-compressor

#### llm-compressor (vLLM project)
- **Status**: Has glm4_moe support (GitHub issue #1703 resolved)
- **Error**: Dependency conflicts broke PyTorch/transformers compatibility
- **Issue**: Installation downgraded ROCm torch to CUDA torch

#### GPTQModel
- **Status**: Claims GLM-4 patches (Jan 23, 2026 release)
- **Error**: Replaced ROCm PyTorch with CUDA versions
- **Issue**: Corrupted torch313-rocm venv completely

#### AMD Quark (AMD-specific, FP8 then MXFP4)
- **Initial**: FP8 quantization started
- **User catch**: FP8 = 31GB minimum (31B params × 1 byte), won't fit in 24GB!
- **Pivot**: Switched to MXFP4 (4-bit, ~15.5GB)
- **Error**: `ValueError: There is no model template defined for 'glm4_moe_lite'`
- **Issue**: Quark has templates for llama, mistral, qwen2_moe, etc., but not glm4_moe_lite

**Result**: ❌ All quantization tools lack support for glm4_moe_lite architecture

### 3. GGUF Support Investigation

#### Discovery
- ✅ SGLang supports GGUF (both main and rocm branches have GGUF code)
- ✅ User has existing GGUF files from llama.cpp:
  - Q4_K_XL: 17GB, 200K context
  - Q5_K_XL: 21GB, 95K context

#### Attempt
- Created flexible startup script for both Q4/Q5
- Tried rocm branch: sgl_kernel incompatibility
- Tried main branch: same sgl_kernel error

#### Critical Error
```
ImportError: /opt/rocm-7.1.1/lib/libamdhip64.so.7:
undefined symbol: hsa_amd_memory_get_preferred_copy_engine, version ROCR_1
```

**Root cause**: sgl_kernel library compiled against different ROCm version

**Result**: ❌ Cannot run SGLang (any format) due to library incompatibility

## Root Causes

### 1. GLM-4.7-Flash Architecture
- Uses custom `glm4_moe_lite` MoE architecture
- Too new/specialized for standard quantization tools
- Poor ecosystem support

### 2. ROCm Environment
- sgl_kernel library incompatible with ROCm 7.1.1
- Blocks all SGLang usage (not just GGUF)
- Affects both main and rocm branches

### 3. VRAM Constraints
- 31B parameters need careful quantization
- FP8 (8-bit) = ~31GB minimum ❌
- 4-bit = ~15.5GB ✅
- But 4-bit tools don't support glm4_moe_lite

## Working Solution

### llama.cpp (Current Setup) ✅

**Q4_K_XL** - ~/llama.cpp/models/GLM-4.7-Flash-UD-Q4_K_XL.gguf
- Size: 17GB
- Context: 200K tokens (full)
- Quality: 4-bit
- Performance: ~10 tok/sec baseline

**Q5_K_XL** - ~/llama.cpp/models/GLM-4.7-Flash-UD-Q5_K_XL.gguf
- Size: 21GB
- Context: 95K tokens (reduced)
- Quality: 5-bit (better)
- Performance: ~10 tok/sec baseline

**Why it works**:
- No sgl_kernel dependency
- Direct GGUF support
- Proven ROCm compatibility
- Already set up and tested

## Next Steps Options

### Option 1: Stick with llama.cpp (Recommended)
**Pros**:
- Already working
- Good performance baseline
- Full/large context support
- No compatibility issues

**Cons**:
- No prefix caching benefits of SGLang
- Slower than SGLang could be

### Option 2: Fix sgl_kernel for ROCm 7.1.1
```bash
source ~/python3-venv/torch313-rocm/bin/activate
uv pip uninstall sgl_kernel
uv pip install --no-binary sgl_kernel --force-reinstall sgl_kernel
```

**Pros**:
- Could enable SGLang with GGUF
- Access to prefix caching

**Cons**:
- Compilation may fail
- Time investment: 30-60 minutes
- No guarantee of success

### Option 3: Try vLLM Instead
vLLM has better ROCm support and GGUF compatibility.

```bash
uv pip install vllm
vllm serve ~/llama.cpp/models/GLM-4.7-Flash-UD-Q5_K_XL.gguf
```

**Pros**:
- Better ROCm compatibility
- Active development
- Similar features to SGLang

**Cons**:
- Need to learn different API
- May have different issues

### Option 4: Use Different Model
Switch to a model with excellent quantization support:

**Qwen2.5-Coder-7B-Instruct**
- Excellent coding performance
- Many 4-bit quantizations available
- Well-supported in SGLang/vLLM
- Will "just work"

**DeepSeek-Coder-V2-Lite-Instruct**
- Single GPU friendly
- Good quantization support

**Pros**:
- Known to work with SGLang
- Better tooling support
- Proven compatibility

**Cons**:
- Not GLM-4.7-Flash
- Different model capabilities

### Option 5: Run Benchmarks with llama.cpp
Use existing setup to establish baseline, then decide:

```bash
# Already working on port 8082
python3 bench_comprehensive.py --base http://192.168.1.251:8082 --runs 3
```

Measure actual performance, then decide if SGLang worth pursuing.

## Files Created This Session

### Working Files
- `bench_comprehensive.py` - Comprehensive benchmark script (ready to use)
- `run_sglang_8081_gguf.sh` - Flexible GGUF startup script (blocked by sgl_kernel)
- `LEARNINGS.md` - All friction points documented
- `MEMORY.md` - Session history
- `TESTING.md` - Testing guide
- `QUANTIZATION_GUIDE.md` - DIY quantization guide (blocked by architecture support)

### Failed Attempts
- `quantize_glm.py` - AutoAWQ script
- `quantize_glm_llmcompressor.py` - llm-compressor script
- `quantize_glm_quark.py` - AMD Quark MXFP4 script
- Various startup scripts for different quantized models

### Environment
- `~/python3-venv/torch313-rocm/` - Main venv (ROCm 2.10.0+rocm6.3, restored)
- `~/python3-venv/quark-quantization/` - Isolated Python 3.10 venv for Quark

## Recommendation

**Start with Option 5**: Run benchmarks on your working llama.cpp setup to establish actual baseline performance. If ~10 tok/sec with prefix caching meets your needs, stick with llama.cpp.

If you need faster inference, then try **Option 3 (vLLM)** as it has better ROCm support than SGLang.

Only pursue GLM-4.7-Flash + SGLang if you're willing to invest significant debugging time on sgl_kernel compilation or consider **Option 4 (different model)** for proven compatibility.

## Key Learnings

1. **Custom architectures have poor tooling support** - GLM-4's glm4_moe_lite is too specialized
2. **VRAM math is critical** - Always calculate: params × bytes/param before starting
3. **ROCm compatibility is fragile** - Pre-compiled binaries often don't work
4. **GGUF is portable** - Your existing GGUF files could work with multiple tools if dependencies allow
5. **Working solution > theoretical best** - llama.cpp works now; SGLang might never work

## Time Investment Summary

- Total session time: ~4-5 hours
- DIY quantization attempts: ~2 hours
- GGUF investigation: ~1 hour
- Environment fixes: ~1-2 hours

**Result**: Comprehensive understanding of limitations, working baseline (llama.cpp), clear path forward
