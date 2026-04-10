#!/bin/bash

# SGLang server for GLM-4.7-Flash GGUF
# Usage: ./run_sglang_8081_gguf.sh [q4|q5]
# Default: q5 (95K context)

set -e

# Choose quantization (default Q5)
QUANT="${1:-q5}"

if [[ "$QUANT" == "q4" ]]; then
    MODEL_FILE="GLM-4.7-Flash-UD-Q4_K_XL.gguf"
    CONTEXT_LEN=200000  # Full context
    MODEL_SIZE="17GB (4-bit)"
elif [[ "$QUANT" == "q5" ]]; then
    MODEL_FILE="GLM-4.7-Flash-UD-Q5_K_XL.gguf"
    CONTEXT_LEN=95000   # Reduced context
    MODEL_SIZE="21GB (5-bit)"
else
    echo "Error: Invalid quantization. Use 'q4' or 'q5'"
    echo "Usage: $0 [q4|q5]"
    exit 1
fi

# Use ROCm venv
source "${HOME}/python3-venv/torch313-rocm/bin/activate"

# Use main branch (better compatibility)
export PYTHONPATH="${HOME}/sglang-rocm-glm-4.7-flash/sglang-src/python"

# GGUF model path
MODEL_PATH="${HOME}/llama.cpp/models/${MODEL_FILE}"

if [[ ! -f "$MODEL_PATH" ]]; then
    echo "Error: Model file not found: $MODEL_PATH"
    exit 1
fi

echo "=================================================="
echo "Starting SGLang server with GGUF model"
echo "=================================================="
echo "Model: ${MODEL_FILE} (${MODEL_SIZE})"
echo "Context: ${CONTEXT_LEN} tokens"
echo "Port: 8081"
echo "ROCm: AMD 7900 XTX"
echo "=================================================="
echo ""

# Start server
exec python3 -m sglang.launch_server \
  --model-path "${MODEL_PATH}" \
  --host 0.0.0.0 \
  --port 8081 \
  --mem-fraction-static 0.85 \
  --max-total-tokens 32768 \
  --context-length ${CONTEXT_LEN} \
  --trust-remote-code
