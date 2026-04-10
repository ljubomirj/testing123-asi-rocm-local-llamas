#!/usr/bin/env python3
"""
Quantize GLM-4.7-Flash to AWQ 4-bit with group_size=32
Optimized for AMD 7900 XTX (24GB)
"""
import os
import torch
from awq import AutoAWQForCausalLM
from transformers import AutoTokenizer

# Configuration
BASE_MODEL = "zenlm/zen-coder-flash"  # or "zai-org/GLM-4.7-Flash"
OUTPUT_PATH = "/home/ljubomir/sglang-rocm-glm-4.7-flash/models-glm-4.7-awq-gs32"
GROUP_SIZE = 32  # 32 = better quality, 128 = smaller/faster

# Quantization config
QUANT_CONFIG = {
    "zero_point": True,
    "q_group_size": GROUP_SIZE,
    "w_bit": 4,
    "version": "GEMM"  # Better compatibility
}

def main():
    print(f"{'='*60}")
    print(f"AutoAWQ Quantization Script")
    print(f"{'='*60}")
    print(f"Base Model: {BASE_MODEL}")
    print(f"Output: {OUTPUT_PATH}")
    print(f"Group Size: {GROUP_SIZE}")
    print(f"Expected time: 1-2 hours for 30B MoE model")
    print(f"RAM needed: ~64GB during quantization")
    print(f"{'='*60}\n")

    # Check HF token
    if "HF_TOKEN" in os.environ:
        print("✓ HF_TOKEN found - using authenticated download")
    else:
        print("⚠ HF_TOKEN not set - may be rate limited")

    # Load model
    print("\n[1/4] Loading base model...")
    print(f"  This will download ~50-60GB if not cached")
    model = AutoAWQForCausalLM.from_pretrained(
        BASE_MODEL,
        device_map="cpu",  # Load to CPU first to avoid GPU OOM
        use_auth_token=os.environ.get("HF_TOKEN")
    )

    # Load tokenizer
    print("\n[2/4] Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(
        BASE_MODEL,
        use_auth_token=os.environ.get("HF_TOKEN"),
        trust_remote_code=True
    )

    # Quantize
    print("\n[3/4] Quantizing model...")
    print(f"  Config: {QUANT_CONFIG}")
    print(f"  This will take 1-2 hours - grab coffee ☕")

    model.quantize(
        tokenizer,
        quant_config=QUANT_CONFIG,
        # Use calibration data (auto-provided by AutoAWQ)
    )

    # Save
    print("\n[4/4] Saving quantized model...")
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    model.save_quantized(OUTPUT_PATH)
    tokenizer.save_pretrained(OUTPUT_PATH)

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
    print(f"Model size: {result.stdout.split()[0]}")

    print(f"\nNext steps:")
    print(f"1. Update run_sglang_8081.sh to use:")
    print(f"   --model-path {OUTPUT_PATH}")
    print(f"   --quantization awq")
    print(f"2. Start server and test!")

    # Cleanup
    print(f"\nCleaning up GPU memory...")
    del model
    torch.cuda.empty_cache()

    print(f"Done! 🎉")

if __name__ == "__main__":
    main()
