#!/bin/bash

# Start vLLM server with GLM-4.7-Flash GGUF on port 8081
# Usage: ./run_vllm_8081_gguf.sh [q4|q5]
# Default: q5

set -e

# Activate venv
source ~/python3-venv/torch313-rocm/bin/activate

# Set quantization level (default: q5)
QUANT="${1:-q5}"

# Select model file and context length based on quantization
if [[ "$QUANT" == "q4" ]]; then
    MODEL_FILE="GLM-4.7-Flash-UD-Q4_K_XL.gguf"
    CONTEXT_LEN=200000
    echo "Using Q4_K_XL quantization (200K context)"
elif [[ "$QUANT" == "q5" ]]; then
    MODEL_FILE="GLM-4.7-Flash-UD-Q5_K_XL.gguf"
    CONTEXT_LEN=95000
    echo "Using Q5_K_XL quantization (95K context)"
else
    echo "Invalid quantization level: $QUANT"
    echo "Usage: $0 [q4|q5]"
    exit 1
fi

MODEL_PATH="/home/ljubomir/llama.cpp/models/$MODEL_FILE"

# Verify model file exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "Error: Model file not found: $MODEL_PATH"
    exit 1
fi

echo "Starting vLLM server on port 8081..."
echo "Model: $MODEL_PATH"
echo "Context length: $CONTEXT_LEN"
echo "=================================="

# Set HuggingFace token
export HF_TOKEN="...secret.token.here..."

# Force ROCm platform (avoid CUDA detection)
export VLLM_PLATFORM=rocm

# Start vLLM with GGUF support
# NOTE: vLLM's GGUF support may require specific flags - adjust as needed
vllm serve "$MODEL_PATH" \
    --port 8081 \
    --host 0.0.0.0 \
    --gpu-memory-utilization 0.95 \
    --max-model-len $CONTEXT_LEN \
    --enable-prefix-caching \
    --enable-chunked-prefill \
    --tensor-parallel-size 1
