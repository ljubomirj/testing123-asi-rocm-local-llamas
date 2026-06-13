#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBSET_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_subset.sh"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"
DEVICE="${DEVICE:-ROCm0}"
GPU_LAYERS="${GPU_LAYERS:-all}"

MODEL_NAME="${MODEL_NAME:-Qwen3.6-27B-IQ4_NL}"
MODEL_PATH="${MODEL_PATH:-$HOME/llama.cpp/models/Qwen3.6-27B-IQ4_NL.gguf}"

THINKING_MODE="${THINKING_MODE:-on}"  # on|off - testing ON only
CTX_SIZE="${CTX_SIZE:-163840}"
MAX_TOKENS="${MAX_TOKENS:-10240}"
SERVER_MAX_TOKENS="${SERVER_MAX_TOKENS:-$MAX_TOKENS}"
OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1800}"

CACHE_RAM="${CACHE_RAM:-16384}"
CACHE_REUSE="${CACHE_REUSE:-512}"
BATCH_SIZE="${BATCH_SIZE:-2048}"
UBATCH_SIZE="${UBATCH_SIZE:-512}"
THREADS_BATCH="${THREADS_BATCH:-10}"
THREADS="${THREADS:-8}"

# Qwen3.6 recommended sampling: temp=1.0, top_p=0.95, top_k=20, presence_penalty=1.5
# For coding tasks: temp=0.0, top_p=1.0
SERVER_TEMP="${SERVER_TEMP:-0.0}"
SERVER_TOP_P="${SERVER_TOP_P:-1.0}"
SERVER_TOP_K="${SERVER_TOP_K:-0}"
SERVER_PRESENCE_PENALTY="${SERVER_PRESENCE_PENALTY:-0.0}"
SERVER_REPEAT_PENALTY="${SERVER_REPEAT_PENALTY:-1.0}"

# Reasoning budget for thinking ON mode: 4096 thinking tokens
REASONING_BUDGET="${REASONING_BUDGET:-4096}"
REASONING_BUDGET_MESSAGE="${REASONING_BUDGET_MESSAGE:-Reasoning budget exhausted. Stop thinking and provide the best final answer now.}"

RUN_LABEL_BASE="${RUN_LABEL_BASE:-qwen36_27b_gigul2}"
RUN_LABEL="${RUN_LABEL:-${RUN_LABEL_BASE}_${THINKING_MODE}_total${MAX_TOKENS}}"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/runs/livecodebench_${RUN_LABEL}_$(date +%Y%m%d_%H%M%S)}"

if [[ ! -x "$SUBSET_SCRIPT" ]]; then
  echo "Missing executable subset script: $SUBSET_SCRIPT"
  exit 1
fi

# Server is already running - skip server startup
# But verify it's accessible
if ! curl -fsS "http://$HOST:$PORT/v1/models" >/dev/null 2>&1; then
  echo "Server not responding at http://$HOST:$PORT/v1"
  echo "Please start the server first with: ~/llama.cpp/llama_server_qwen3.6-27b_gigul2.sh"
  exit 1
fi

echo "Server is running at http://$HOST:$PORT/v1"

mkdir -p "$RUN_ROOT"
RUN_LOG="$RUN_ROOT/${MODEL_NAME}.run.log"
LAUNCH_LOG="$RUN_ROOT/launch.log"

case "$THINKING_MODE" in
  on)
    CHAT_TEMPLATE_KWARGS_JSON='{"enable_thinking":true,"preserve_thinking":true}'
    ;;
  off)
    CHAT_TEMPLATE_KWARGS_JSON='{"enable_thinking":false}'
    ;;
  *)
    echo "THINKING_MODE must be 'on' or 'off', got: $THINKING_MODE"
    exit 1
    ;;
esac

env_args=(
  "OPENAI_API_BASE=http://$HOST:$PORT/v1"
  "OPENAI_BASE_URL=http://$HOST:$PORT/v1"
  "OPENAI_TIMEOUT=$OPENAI_TIMEOUT"
  "MAX_TOKENS=$MAX_TOKENS"
  "TEMP=0.0"
  "TOP_P=1.0"
  "N=1"
  "RESET_OUTPUT=1"
  "LOG_DIR=$RUN_ROOT"
  "LCB_CHAT_TEMPLATE_KWARGS_JSON=$CHAT_TEMPLATE_KWARGS_JSON"
)

if [[ "$THINKING_MODE" == "on" ]]; then
  env_args+=("LCB_REASONING_FORMAT=deepseek")
fi

{
  echo "Script: $0"
  echo "Run root: $RUN_ROOT"
  echo "Thinking mode: $THINKING_MODE"
  echo "Max tokens: $MAX_TOKENS"
  echo "Reasoning budget: ${REASONING_BUDGET:-n/a}"
  echo "Subset env:"
  printf '  %q ' "${env_args[@]}"
  echo
} >"$LAUNCH_LOG"

echo "Starting LCB test..."
echo "Model: $MODEL_NAME"
echo "Thinking mode: $THINKING_MODE"
echo "Max tokens: $MAX_TOKENS"

env "${env_args[@]}" \
  "$SUBSET_SCRIPT" "$MODEL_NAME" | tee "$RUN_LOG"

echo ""
echo "Run complete."
echo "Run root: $RUN_ROOT"
