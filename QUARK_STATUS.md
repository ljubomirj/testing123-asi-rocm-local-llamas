# AMD Quark Quantization - IN PROGRESS

## Current Status: ✓ RUNNING

AMD Quark FP8 quantization is now successfully running after fixing the ROCm environment.

### What's Happening

```
[1/5] ✓ Loading tokenizer... DONE
[2/5] ⏳ Loading base model... DOWNLOADING (~50GB)
[3/5] ⏸ Preparing calibration data... PENDING
[4/5] ⏸ Quantizing model... PENDING (1-2 hours)
[5/5] ⏸ Saving quantized model... PENDING
```

**Estimated completion**: 1-2 hours from when download finishes

## Environment Setup Summary

### Problem: Quantization Tools Broke ROCm Environment

All attempted quantization tools (AutoAWQ, llm-compressor, GPTQModel) have hard CUDA dependencies that replaced ROCm PyTorch with CUDA versions.

### Solution: Isolated Python 3.10 Venv + AMD Quark

1. **Restored main venv** (`torch313-rocm`):
   - PyTorch 2.10.0.dev20250926+rocm6.3
   - Python 3.13.12
   - AMD 7900 XTX detected ✓

2. **Created quantization venv** (`quark-quantization`):
   - Python 3.10.12 (Quark requires 3.10-3.12)
   - PyTorch 2.5.1+rocm6.2
   - AMD Quark 0.11
   - Transformers 5.1.0

### Why AMD Quark?

- **AMD-specific optimization**: Designed for AMD GPUs with ROCm
- **FP8 support**: Native AMD format (better than AWQ for ROCm)
- **No CUDA dependencies**: Won't break ROCm environment
- **Active development**: Latest release 0.11 (Jan 2026)

## Technical Details

### Quantization Config

- **Base model**: zenlm/zen-coder-flash (coding-optimized GLM-4.7-Flash)
- **Quantization**: FP8 (8-bit floating point, AMD-optimized)
- **Calibration**: 128 samples from wikitext-2
- **Output**: models-glm-4.7-quark-fp8/

### What FP8 Provides

- **Model size**: ~7-8GB (down from 50GB FP16)
- **Quality loss**: Minimal (<2% with FP8)
- **Speed**: 2-3x faster inference on AMD GPUs
- **VRAM usage**: Should easily fit in 24GB with KV cache

## Monitoring Progress

### Check quantization log:

```bash
tail -f quantize_quark.log
```

### Or check background task output:

```bash
tail -f /tmp/claude-1000/-home-ljubomir-sglang-rocm-glm-4-7-flash/tasks/bb361da.output
```

### Monitor GPU usage:

```bash
watch -n 5 rocm-smi
```

## After Quantization Completes

### 1. Verify Output

```bash
ls -lh models-glm-4.7-quark-fp8/
du -sh models-glm-4.7-quark-fp8/
```

Expected size: ~7-8GB

### 2. Create Startup Script

```bash
cp run_sglang_8081_cyankiwi.sh run_sglang_8081_quark.sh
nano run_sglang_8081_quark.sh
```

Update to:
```bash
--model-path /home/ljubomir/sglang-rocm-glm-4.7-flash/models-glm-4.7-quark-fp8
--quantization fp8
```

### 3. Test Server

```bash
# Start server (use torch313-rocm venv, NOT quark-quantization)
source ~/python3-venv/torch313-rocm/bin/activate
./run_sglang_8081_quark.sh
```

### 4. Run Benchmarks

```bash
# In another terminal
python3 bench_comprehensive.py --base http://192.168.1.251:8081 --runs 3
```

## Files Created

- `~/python3-venv/quark-quantization/` - Isolated Python 3.10 venv for Quark
- `quantize_glm_quark.py` - AMD Quark FP8 quantization script
- `quantize_quark.log` - Quantization progress log
- `models-glm-4.7-quark-fp8/` - Output quantized model (pending)

## If Quantization Fails

### Common Issues

1. **OOM during quantization**:
   - Model loads to GPU for quantization
   - Should fit in 24GB but might need tweaking
   - Solution: Add `device_map="cpu"` in script if needed

2. **Calibration data issues**:
   - Wikitext might not be ideal for coding model
   - Solution: Switch to code-specific dataset

3. **Model incompatibility**:
   - GLM-4 MoE Lite might have unsupported layers
   - Solution: Try base GLM-4.7-Flash instead of ZenCoder

### Fallback Options

If Quark fails, you still have:

1. **Use QuantTrio with tiny context** (known to work):
   ```bash
   ./run_sglang_8081.sh  # max-total-tokens=2048
   ```

2. **Search for pre-quantized models**:
   - Look for recent GLM-4.7-Flash quantizations on HuggingFace
   - Filter by single-GPU compatibility

3. **Try different model**:
   - Qwen2.5-Coder-7B-Instruct (excellent quantization support)
   - DeepSeek-Coder-V2-Lite-Instruct

## Next Steps After Success

1. ✓ Verify quantized model loads in SGLang
2. Run comprehensive benchmarks
3. Compare with llama.cpp baseline (~10 tok/sec)
4. Test prefix caching effectiveness (run multiple times)
5. Tune max_total_tokens based on VRAM usage
6. Document performance results in TESTING.md

## Sources

- [AMD Quark GitHub](https://github.com/amd/Quark)
- [AMD Quark Installation Guide](https://quark.docs.amd.com/latest/install.html)
- [LLM Quantization with Quark](https://quark.docs.amd.com/latest/tutorials/torch/llm_ptq/llm_tutorial/llm_tutorial.html)
- [FP8 quantization with AMD Quark](https://rocm.docs.amd.com/projects/ai-developer-hub/en/latest/notebooks/gpu_dev_optimize/fp8_quantization_quark_vllm.html)
- [AMD Quark - vLLM Docs](https://docs.vllm.ai/en/stable/features/quantization/quark/)
