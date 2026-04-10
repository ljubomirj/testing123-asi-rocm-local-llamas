#!/bin/bash

# Build vLLM from source for AMD Radeon 7900 XTX (gfx1100) with ROCm 7.1.1
# Based on: https://docs.vllm.ai/en/latest/getting_started/installation/gpu.rocm.inc.html

set -e

# Activate venv
source ~/python3-venv/torch313-rocm/bin/activate

cd ~/sglang-rocm-glm-4.7-flash/vllm-src

echo "===================================="
echo "Building vLLM for ROCm (gfx1100)"
echo "===================================="

# Upgrade pip
pip install --upgrade pip

# Build & install AMD SMI (if not already installed)
if [ -d /opt/rocm/share/amd_smi ]; then
    echo "Installing AMD SMI..."
    uv pip install /opt/rocm/share/amd_smi || echo "AMD SMI install failed (may already be installed)"
fi

# Install dependencies
echo "Installing dependencies..."
uv pip install --upgrade numba scipy huggingface-hub[cli,hf_transfer] setuptools_scm

# Install ROCm-specific requirements
if [ -f requirements/rocm.txt ]; then
    echo "Installing ROCm requirements..."
    uv pip install -r requirements/rocm.txt
fi

# Set architecture for 7900 XTX (gfx1100)
export PYTORCH_ROCM_ARCH="gfx1100"

echo "Building vLLM for gfx1100..."
echo "This may take 5-10 minutes..."

# Build vLLM (use setup.py develop for source builds on ROCm)
python3 setup.py develop

echo "===================================="
echo "vLLM build complete!"
echo "===================================="

# Verify installation
python3 -c "import vllm; print(f'vLLM version: {vllm.__version__}')"
