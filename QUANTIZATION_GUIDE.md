# DIY Quantization Guide - GLM-4.7-Flash for 7900 XTX

## Why Self-Quantize?

Pre-made quantizations have issues:
- **QuantTrio AWQ**: Too large (needs 2 GPUs)
- **cyankiwi**: Uses incompatible compressed-tensors format
- **TheHouseOfTheDude**: Designed for 2 GPUs

**Solution**: Create our own AWQ quantization optimized for single 24GB GPU

## Prerequisites

### System Requirements
- **GPU**: 24GB VRAM (7900 XTX) ✓
- **RAM**: 64GB+ system RAM (for quantization process)
- **Disk**: ~80GB free (base model + quantized output)
- **Time**: 1-2 hours

### Software Setup

```bash
# Activate venv
source ~/python3-venv/torch313-rocm/bin/activate

# Install AutoAWQ
pip install autoawq

# Verify ROCm compatibility
python3 -c "import torch; print(f'ROCm available: {torch.cuda.is_available()}')"
```

## Quantization Process

### Step 1: Choose Base Model

**Option A: ZenCoder-flash** (Recommended for code)
- Fine-tuned for coding tasks
- Same architecture as GLM-4.7-Flash
- ~50-60GB download

**Option B: GLM-4.7-Flash (base)**
- Original model
- General purpose
- ~50-60GB download

### Step 2: Run Quantization

```bash
cd ~/sglang-rocm-glm-4.7-flash
source ~/python3-venv/torch313-rocm/bin/activate
export HF_TOKEN=...

# Run quantization (takes 1-2 hours)
python3 quantize_glm.py 2>&1 | tee quantize.log
```

**What happens:**
1. Downloads base model (~50GB) to HF cache
2. Loads model to CPU (saves GPU memory)
3. Quantizes layer by layer
4. Saves to `models-glm-4.7-awq-gs32/` (~17-18GB)

### Step 3: Configure SGLang

Update startup script to use your quantized model:

```bash
# Create new startup script
cp run_sglang_8081_cyankiwi.sh run_sglang_8081_custom.sh

# Edit to point to your quantized model
nano run_sglang_8081_custom.sh
# Change:
#   --model-path /home/ljubomir/sglang-rocm-glm-4.7-flash/models-glm-4.7-awq-gs32
#   --quantization awq
```

### Step 4: Test

```bash
# Start server
./run_sglang_8081_custom.sh

# In another terminal, test
python3 bench_comprehensive.py --base http://192.168.1.251:8081 --runs 3
```

## Configuration Options

### Group Size Trade-offs

| Group Size | Quality | Model Size | Speed | Memory |
|------------|---------|------------|-------|--------|
| **32** | Best | ~17-18GB | Slower | More VRAM |
| 64 | Good | ~16-17GB | Medium | Medium |
| 128 | OK | ~15-16GB | Faster | Less VRAM |

**Recommendation**: Start with 32 (best quality). If OOM, retry with 64 or 128.

To change group size, edit `quantize_glm.py`:
```python
GROUP_SIZE = 64  # or 128
```

## Troubleshooting

### Out of Memory During Quantization

```bash
# Edit quantize_glm.py and add:
model = AutoAWQForCausalLM.from_pretrained(
    BASE_MODEL,
    device_map="cpu",  # ← Already set
    low_cpu_mem_usage=True,  # ← Add this
    max_memory={0: "20GB"}  # ← Limit GPU usage
)
```

### Slow Download

Already using HF_TOKEN for authenticated downloads (faster).

If still slow:
```bash
# Download separately first
huggingface-cli download zenlm/zen-coder-flash

# Then quantization will use cached version
```

### Quantization Fails

Check logs:
```bash
tail -100 quantize.log
```

Common issues:
- **Insufficient RAM**: Need 64GB+
- **Wrong PyTorch**: Need ROCm-compatible PyTorch
- **Model not found**: Check HF_TOKEN is set

## Alternative: AMD Quark FP8

If AWQ doesn't perform well:

```bash
# Install Quark
pip install quark-amd

# Use FP8 quantization (AMD-optimized)
# See: https://quark.docs.amd.com/latest/pytorch/awq_document.html
```

## Expected Results

After quantization:
- **Model size**: ~17-18GB (down from 50-60GB)
- **VRAM usage**: Should fit in 24GB with KV cache
- **Quality loss**: <1% with group_size=32
- **Speed**: 3x faster than FP16

## Next Steps After Quantization

1. **Start server** with your custom model
2. **Run benchmarks** to measure performance
3. **Compare** with llama.cpp baseline (~10 tok/sec)
4. **Test prefix caching** with multiple runs
5. **Tune** max_total_tokens based on VRAM usage

## Files Created

- `quantize_glm.py` - Main quantization script
- `quantize.log` - Quantization progress log
- `models-glm-4.7-awq-gs32/` - Output quantized model
- `run_sglang_8081_custom.sh` - Server startup script

## Resources

- [AutoAWQ GitHub](https://github.com/casper-hansen/AutoAWQ)
- [AWQ Paper](https://hanlab.mit.edu/projects/awq)
- [AMD Quark Docs](https://quark.docs.amd.com/)
