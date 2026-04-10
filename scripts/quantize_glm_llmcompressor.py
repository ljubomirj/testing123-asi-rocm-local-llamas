#!/usr/bin/env python3
"""
Quantize GLM-4.7-Flash to AWQ 4-bit using llm-compressor
Optimized for AMD 7900 XTX (24GB) with ROCm
"""
import os
from llmcompressor.transformers import oneshot
from llmcompressor.modifiers.quantization import AWQModifier

# Configuration
BASE_MODEL = "zenlm/zen-coder-flash"  # or "zai-org/GLM-4.7-Flash"
OUTPUT_PATH = "/home/ljubomir/sglang-rocm-glm-4.7-flash/models-glm-4.7-awq-gs32"
GROUP_SIZE = 32  # 32 = better quality, 128 = smaller/faster

def main():
    print(f"{'='*60}")
    print(f"llm-compressor AWQ Quantization Script")
    print(f"{'='*60}")
    print(f"Base Model: {BASE_MODEL}")
    print(f"Output: {OUTPUT_PATH}")
    print(f"Group Size: {GROUP_SIZE}")
    print(f"Expected time: 1-2 hours for 30B MoE model")
    print(f"RAM needed: ~64GB during quantization")
    print(f"{'='*60}\n")

    # Check HF token
    hf_token = os.environ.get("HF_TOKEN")
    if hf_token:
        print("✓ HF_TOKEN found - using authenticated download")
    else:
        print("⚠ HF_TOKEN not set - may be rate limited")

    # Create quantization recipe
    recipe = AWQModifier(
        scheme="W4A16",  # 4-bit weights, 16-bit activations
        group_size=GROUP_SIZE,
        targets="Linear",
    )

    print("\n[1/2] Loading base model and quantizing...")
    print(f"  This will download ~50-60GB if not cached")
    print(f"  Quantization takes 1-2 hours - grab coffee ☕")

    # Run oneshot quantization
    oneshot(
        model=BASE_MODEL,
        dataset="wikitext2",  # Default calibration dataset
        recipe=recipe,
        output_dir=OUTPUT_PATH,
        num_calibration_samples=512,
        max_seq_length=4096,
        device_map="auto",
        trust_remote_code=True,
        use_auth_token=hf_token,
    )

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
    print(f"   --quantization awq")
    print(f"2. Start server and test!")
    print(f"\nDone! 🎉")

if __name__ == "__main__":
    main()
