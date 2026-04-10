#!/usr/bin/env python3
"""
Quantize GLM-4.7-Flash using AMD Quark FP8
Optimized for AMD 7900 XTX (24GB) with ROCm
"""
import os
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from quark.torch import LLMTemplate, ModelQuantizer, export_safetensors
from datasets import load_dataset

# Configuration
BASE_MODEL = "zenlm/zen-coder-flash"  # or "zai-org/GLM-4.7-Flash"
OUTPUT_PATH = "/home/ljubomir/sglang-rocm-glm-4.7-flash/models-glm-4.7-quark-mxfp4"
QUANT_SCHEME = "mxfp4"  # 4-bit microscaling FP, AMD-optimized for 24GB VRAM
NUM_CALIB_SAMPLES = 128

def main():
    print(f"{'='*60}")
    print(f"AMD Quark MXFP4 Quantization Script")
    print(f"{'='*60}")
    print(f"Base Model: {BASE_MODEL}")
    print(f"Output: {OUTPUT_PATH}")
    print(f"Quantization: {QUANT_SCHEME}")
    print(f"Calibration samples: {NUM_CALIB_SAMPLES}")
    print(f"Expected time: 1-2 hours for 30B MoE model")
    print(f"{'='*60}\n")

    # Check HF token
    hf_token = os.environ.get("HF_TOKEN")
    if hf_token:
        print("✓ HF_TOKEN found - using authenticated download")
    else:
        print("⚠ HF_TOKEN not set - may be rate limited")

    # Check GPU
    if torch.cuda.is_available():
        print(f"✓ GPU detected: {torch.cuda.get_device_name(0)}")
        print(f"  VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
    else:
        print("⚠ No GPU detected - quantization will be slow")

    print("\n[1/5] Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(
        BASE_MODEL,
        token=hf_token,
        trust_remote_code=True
    )

    print("\n[2/5] Loading base model...")
    print(f"  This will download ~50-60GB if not cached")

    # Load config first and remove any existing quantization config
    from transformers import AutoConfig
    config = AutoConfig.from_pretrained(
        BASE_MODEL,
        token=hf_token,
        trust_remote_code=True
    )
    # Remove existing quantization config if present
    if hasattr(config, 'quantization_config'):
        delattr(config, 'quantization_config')

    model = AutoModelForCausalLM.from_pretrained(
        BASE_MODEL,
        token=hf_token,
        config=config,
        trust_remote_code=True,
        torch_dtype=torch.float16,
        device_map="auto",  # Use GPU if available
        ignore_mismatched_sizes=True,  # Allow MoE architecture mismatches
    )

    print("\n[3/5] Preparing calibration data...")
    # Use wikitext for calibration
    dataset = load_dataset("wikitext", "wikitext-2-raw-v1", split="train")

    def prepare_calib_data():
        """Prepare calibration DataLoader"""
        samples = []
        for i in range(min(NUM_CALIB_SAMPLES, len(dataset))):
            text = dataset[i]["text"]
            if len(text) > 100:  # Skip short texts
                tokens = tokenizer(
                    text,
                    return_tensors="pt",
                    max_length=512,
                    truncation=True,
                    padding="max_length"
                )
                samples.append(tokens)
                if len(samples) >= NUM_CALIB_SAMPLES:
                    break

        print(f"  Prepared {len(samples)} calibration samples")
        return torch.utils.data.DataLoader(samples, batch_size=1, shuffle=False)

    calib_dataloader = prepare_calib_data()

    print("\n[4/5] Quantizing model with AMD Quark...")
    print(f"  Using {QUANT_SCHEME} quantization (4-bit, AMD-optimized)")
    print(f"  Expected output: ~15-16GB (down from 50GB)")
    print(f"  This will take 1-2 hours - grab coffee ☕")

    # Get quantization config
    try:
        template = LLMTemplate.get(model.config.model_type)
        quant_config = template.get_config(scheme=QUANT_SCHEME)
        print(f"  ✓ Using quantization config for model type: {model.config.model_type}")
    except Exception as e:
        print(f"  ⚠ Model type '{model.config.model_type}' not in templates")
        print(f"  Attempting generic quantization config...")
        # Fallback: create generic config
        from quark.torch.quantization.config.config import Config, QuantizationConfig
        quant_config = Config(
            global_quant_config=QuantizationConfig(
                quant_algo="fp8",
                w_bit=8,
                a_bit=8,
            )
        )

    # Quantize
    quantizer = ModelQuantizer(quant_config, multi_device=True)
    quantized_model = quantizer.quantize_model(model, calib_dataloader)

    print("\n[5/5] Saving quantized model...")
    os.makedirs(OUTPUT_PATH, exist_ok=True)

    # Export model
    export_safetensors(model=quantized_model, output_dir=OUTPUT_PATH)

    # Save tokenizer
    tokenizer.save_pretrained(OUTPUT_PATH)

    # Save config
    model.config.save_pretrained(OUTPUT_PATH)

    print(f"\n{'='*60}")
    print(f"✓ Quantization complete!")
    print(f"{'='*60}")
    print(f"Model saved to: {OUTPUT_PATH}")

    # Print expected size
    import subprocess
    result = subprocess.run(
        ["du", "-sh", OUTPUT_PATH],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print(f"Model size: {result.stdout.split()[0]}")

    print(f"\nNext steps:")
    print(f"1. Update run_sglang_8081.sh to use:")
    print(f"   --model-path {OUTPUT_PATH}")
    print(f"   --quantization compressed-tensors  # or mxfp4 if supported")
    print(f"2. Start server and test!")

    # Cleanup
    print(f"\nCleaning up GPU memory...")
    del model
    del quantized_model
    torch.cuda.empty_cache()

    print(f"Done! 🎉")

if __name__ == "__main__":
    main()
