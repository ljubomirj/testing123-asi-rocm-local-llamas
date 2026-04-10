#!/usr/bin/env bash
set -euo pipefail

ROCM_ROOT="/opt/rocm-7.1.1"

if [[ ! -d "${ROCM_ROOT}" ]]; then
  echo "ROCm 7.1.1 not found at ${ROCM_ROOT}" >&2
  exit 1
fi

export ROCM_PATH="${ROCM_ROOT}"
export ROCM_HOME="${ROCM_ROOT}"
export HIP_PATH="${ROCM_ROOT}"
export SGLANG_USE_AITER=0
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
export PATH="${ROCM_ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${ROCM_ROOT}/lib:${ROCM_ROOT}/lib64:${LD_LIBRARY_PATH:-}"
export TORCHDYNAMO_DISABLE=1
export PYTHONPATH="${HOME}/sglang-rocm-glm-4.7-flash/sglang-src/python"

# Fast 8-bit KV cache (allow override via env)
export SGLANG_INT8_KV_HIP="${SGLANG_INT8_KV_HIP:-0}"
export SGLANG_INT8_KV_HIP_DEBUG="${SGLANG_INT8_KV_HIP_DEBUG:-0}"
# Default MoE runner backend (override via env)
export SGLANG_MOE_RUNNER_BACKEND="${SGLANG_MOE_RUNNER_BACKEND:-triton}"

# Disable CUDA graph when using the custom HIP int8 KV kernel (can override).
if [[ "${SGLANG_INT8_KV_HIP}" == "1" ]]; then
  export SGLANG_DISABLE_CUDA_GRAPH="${SGLANG_DISABLE_CUDA_GRAPH:-1}"
fi

extra_args=()
if [[ "${SGLANG_DISABLE_CUDA_GRAPH:-0}" == "1" ]]; then
  extra_args+=(--disable-cuda-graph)
fi

# v3 1-Feb-2026
exec python3 -m sglang.launch_server \
  --model-path /home/ljubomir/sglang-rocm-glm-4.7-flash/models--QuantTrio--GLM-4.7-Flash-AWQ/snapshots/88e3d3d913c0d97c8f505cdc03433c48226bedc3 \
  --tp-size 1 \
  --tool-call-parser glm47  \
  --reasoning-parser glm45 \
  --mem-fraction-static 0.85 \
  --max-total-tokens 32768 \
  --max-prefill-tokens 32768 \
  --allow-auto-truncate \
  --served-model-name glm-4.7-flash \
  --dtype float16 \
  --quantization moe_wna16 \
  --trust-remote-code \
  --moe-runner-backend "${SGLANG_MOE_RUNNER_BACKEND}" \
  --host 0.0.0.0 \
  --port 8000 \
  "${extra_args[@]}"

# # v2 30-Jan-2026 with int8 for KV-cache
# exec python3 -m sglang.launch_server \
# 	--kv-cache-dtype int8 \
#   --model-path /home/ljubomir/sglang-rocm-glm-4.7-flash/models--QuantTrio--GLM-4.7-Flash-AWQ/snapshots/88e3d3d913c0d97c8f505cdc03433c48226bedc3 \
#   --tp-size 1 \
#   --tool-call-parser glm47  \
#   --reasoning-parser glm45 \
#   --mem-fraction-static 0.85 \
#   --max-total-tokens 32768 \
#   --max-prefill-tokens 32768 \
#   --allow-auto-truncate \
#   --served-model-name glm-4.7-flash \
#   --dtype float16 \
#   --quantization moe_wna16 \
#   --trust-remote-code \
#   --moe-runner-backend "${SGLANG_MOE_RUNNER_BACKEND}" \
#   --host 0.0.0.0 \
#   --port 8000 \
#   "${extra_args[@]}"

# # v1a 30-Jan-2026 initial try
# exec python3 -m sglang.launch_server \
#   --model-path /home/ljubomir/sglang-rocm-glm-4.7-flash/models--QuantTrio--GLM-4.7-Flash-AWQ/snapshots/88e3d3d913c0d97c8f505cdc03433c48226bedc3 \
#   --tp-size 1 \
#   --tool-call-parser glm47  \
#   --reasoning-parser glm45 \
#   --mem-fraction-static 0.20 \
#   --max-total-tokens 32768 \
#   --max-prefill-tokens 32768 \
#   --allow-auto-truncate \
#   --served-model-name glm-4.7-flash \
#   --dtype float16 \
#   --quantization moe_wna16 \
#   --trust-remote-code \
#   --host 0.0.0.0 \
#   --port 8000

# # 30-Jan-2026
# # https://huggingface.co/cyankiwi/GLM-4.7-Flash-AWQ-4bit
# # https://docs.z.ai/guides/capabilities/thinking-mode
# exec python3 -m sglang.launch_server \
#   --model-path /home/ljubomir/sglang-rocm-glm-4.7-flash/models--QuantTrio--GLM-4.7-Flash-AWQ/snapshots/88e3d3d913c0d97c8f505cdc03433c48226bedc3 \
#   --tp-size 1 \
#   --tool-call-parser glm47  \
#   --reasoning-parser glm45 \
#   --speculative-algorithm EAGLE \
#   --speculative-num-steps 3 \
#   --speculative-eagle-topk 1 \
#   --speculative-num-draft-tokens 4 \
#   --mem-fraction-static 0.20 \
#   --max-total-tokens 32768 \
#   --max-prefill-tokens 32768 \
#   --allow-auto-truncate \
#   --served-model-name glm-4.7-flash \
#   --dtype float16 \
#   --quantization moe_wna16 \
#   --trust-remote-code \
#   --host 0.0.0.0 \
#   --port 8000

# # v1 29-Jan-2026 initial try
# exec python3 -m sglang.launch_server \
#   --model-path /home/ljubomir/sglang-rocm-glm-4.7-flash/models--QuantTrio--GLM-4.7-Flash-AWQ/snapshots/88e3d3d913c0d97c8f505cdc03433c48226bedc3 \
#   --tp-size 1 \
#   --mem-fraction-static 0.20 \
#   --max-total-tokens 32768 \
#   --max-prefill-tokens 32768 \
#   --allow-auto-truncate \
#   --served-model-name glm-4.7-flash \
#   --dtype float16 \
#   --quantization moe_wna16 \
#   --trust-remote-code \
#   --host 0.0.0.0 \
#   --port 8000
