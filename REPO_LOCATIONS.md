# Repository Checkout Locations

## For Future Updates When Support Improves

### Triton for ROCm
- **Location**: `~/sglang-rocm-glm-4.7-flash/triton-rocm/`
- **Source**: https://github.com/ROCm/triton.git
- **Current commit**: f9e5bf54 (validated for vLLM)
- **Installed to**: `~/python3-venv/torch313-rocm/` (Python 3.13)
- **Version**: 3.4.0
- **To update**:
  ```bash
  cd ~/sglang-rocm-glm-4.7-flash/triton-rocm/
  git pull
  git checkout <new-validated-commit>
  source ~/python3-venv/torch313-rocm/bin/activate
  python3 setup.py install
  ```

### vLLM
- **Location**: `~/sglang-rocm-glm-4.7-flash/vllm-src/`
- **Source**: https://github.com/vllm-project/vllm.git
- **Current commit**: 2c32558a3 (bugfixes)
- **Version**: 0.15.2rc1.dev159+g2c32558a3
- **Built for**: gfx1100 (AMD 7900 XTX)
- **Patch applied**: Disabled CUDA detection in `vllm/platforms/__init__.py` (line 59-61)
- **To update**:
  ```bash
  cd ~/sglang-rocm-glm-4.7-flash/vllm-src/
  git pull
  # Check if deepseek2 GGUF support added:
  grep -r "deepseek2" vllm/ --include="*.py"
  # Rebuild:
  source ~/python3-venv/torch313-rocm/bin/activate
  export PYTORCH_ROCM_ARCH="gfx1100"
  python3 setup.py develop
  ```
- **Watch for**:
  - GGUF deepseek2 architecture support in transformers or vLLM
  - Check: https://github.com/vllm-project/vllm/issues (search "deepseek2 gguf")

### SGLang
- **Location (main)**: `~/sglang-rocm-glm-4.7-flash/sglang-src/`
- **Location (rocm)**: `~/sglang-rocm-glm-4.7-flash/sglang-rocm-branch/`
- **Source**: https://github.com/sgl-project/sglang.git
- **Main branch commit**: 835396fb3
- **ROCm branch**: rocm-7900xtx-sgl-kernel (commit 0e1185513)
- **Blocking issue**: `undefined symbol: hsa_amd_memory_get_preferred_copy_engine, version ROCR_1`
- **To update**:
  ```bash
  cd ~/sglang-rocm-glm-4.7-flash/sglang-src/
  git pull
  # Test if ROCm 7.1.1 compatibility fixed:
  source ~/python3-venv/torch313-rocm/bin/activate
  python -c "from sglang import sgl; print('SGLang loaded successfully')"
  ```
- **Watch for**:
  - ROCm 7.1.x compatibility fixes
  - New sgl_kernel builds for ROCm 7.1.1
  - Check: https://github.com/sgl-project/sglang/issues (search "rocm 7.1")

### System Info
- **ROCm Version**: 7.1.1 (`/opt/rocm-7.1.1/`)
- **GPU**: AMD Radeon RX 7900 XTX (gfx1100, 24GB VRAM)
- **Python venv**: `~/python3-venv/torch313-rocm/` (Python 3.13.12)
- **PyTorch**: 2.10.0.dev20250926+rocm6.3

### Quick Test Commands

**Test Triton:**
```bash
source ~/python3-venv/torch313-rocm/bin/activate
python3 -c "import triton; print(f'Triton {triton.__version__}')"
```

**Test vLLM:**
```bash
source ~/python3-venv/torch313-rocm/bin/activate
python3 -c "import vllm; print(f'vLLM {vllm.__version__}')"
```

**Test SGLang:**
```bash
source ~/python3-venv/torch313-rocm/bin/activate
python3 -c "from sglang import sgl; print('SGLang OK')"
```

### Watch List for Updates

1. **vLLM GGUF deepseek2 support**:
   - File to watch: `transformers/src/transformers/modeling_gguf_pytorch_utils.py`
   - Or: vLLM may add custom deepseek2 GGUF loader

2. **SGLang ROCm 7.1+ support**:
   - Check releases for sgl_kernel compatibility updates
   - May need new prebuilt wheels or source rebuild

3. **Transformers deepseek2 support**:
   - HuggingFace transformers library updates
   - Check: https://github.com/huggingface/transformers/releases
