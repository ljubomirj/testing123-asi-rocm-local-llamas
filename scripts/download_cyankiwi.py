#!/usr/bin/env python3
"""Download cyankiwi GLM-4.7-Flash-AWQ-4bit model"""
from huggingface_hub import snapshot_download
import os

print("Starting download of cyankiwi/GLM-4.7-Flash-AWQ-4bit...")
print("This will download ~17GB of model files")

local_dir = os.path.expanduser("~/sglang-rocm-glm-4.7-flash/models-cyankiwi-GLM-4.7-Flash-AWQ-4bit")

snapshot_download(
    repo_id="cyankiwi/GLM-4.7-Flash-AWQ-4bit",
    local_dir=local_dir,
    local_dir_use_symlinks=False,
    resume_download=True,
)

print(f"Download complete! Model saved to: {local_dir}")
