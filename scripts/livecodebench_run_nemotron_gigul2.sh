#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBSET_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_subset.sh"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"
DEVICE="${DEVICE:-ROCm0}"
GPU_LAYERS="${GPU_LAYERS:-all}"

MODEL_NAME="${MODEL_NAME:-Nemotron-Cascade-2-30B-A3B-IQ4_XS}"
MODEL_PATH="${MODEL_PATH:-$HOME/llama.cpp/models/Nemotron-Cascade-2-30B-A3B-IQ4_XS.gguf}"

THINKING_MODE="${THINKING_MODE:-on}"  # on|off
CTX_SIZE="${CTX_SIZE:-150000}"
MAX_TOKENS="${MAX_TOKENS:-10000}"
SERVER_MAX_TOKENS="${SERVER_MAX_TOKENS:-$MAX_TOKENS}"
OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1800}"

CACHE_RAM="${CACHE_RAM:-16384}"
CACHE_REUSE="${CACHE_REUSE:-512}"
BATCH_SIZE="${BATCH_SIZE:-2048}"
UBATCH_SIZE="${UBATCH_SIZE:-512}"
THREADS_BATCH="${THREADS_BATCH:-10}"
THREADS="${THREADS:-10}"

REASONING_BUDGET="${REASONING_BUDGET:-5000}"
REASONING_BUDGET_MESSAGE="${REASONING_BUDGET_MESSAGE:-Thinking budget exhausted. Stop thinking and provide the best final answer now.}"

RUN_LABEL_BASE="${RUN_LABEL_BASE:-nemotron_gigul2}"
RUN_LABEL="${RUN_LABEL:-${RUN_LABEL_BASE}_${THINKING_MODE}_total${MAX_TOKENS}}"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/runs/livecodebench_${RUN_LABEL}_$(date +%Y%m%d_%H%M%S)}"

if [[ ! -x "$SUBSET_SCRIPT" ]]; then
  echo "Missing executable subset script: $SUBSET_SCRIPT"
  exit 1
fi
if [[ ! -x "$SERVER_BIN" ]]; then
  echo "Missing llama-server binary: $SERVER_BIN"
  exit 1
fi
if [[ ! -f "$MODEL_PATH" ]]; then
  echo "Missing model file: $MODEL_PATH"
  exit 1
fi

case "$THINKING_MODE" in
  on)
    SERVER_REASONING_FORMAT="deepseek"
    SERVER_REASONING_FLAG="on"
    EXPECTED_THINKING_LOG="1"
    CHAT_TEMPLATE_KWARGS_JSON='{"enable_thinking":true}'
    ;;
  off)
    SERVER_REASONING_FORMAT="none"
    SERVER_REASONING_FLAG="off"
    EXPECTED_THINKING_LOG="0"
    CHAT_TEMPLATE_KWARGS_JSON='{"enable_thinking":false}'
    ;;
  *)
    echo "THINKING_MODE must be 'on' or 'off', got: $THINKING_MODE"
    exit 1
    ;;
esac

mkdir -p "$RUN_ROOT"
SERVER_LOG="$RUN_ROOT/${MODEL_NAME}.server.log"
RUN_LOG="$RUN_ROOT/${MODEL_NAME}.run.log"
LAUNCH_LOG="$RUN_ROOT/launch.log"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_server() {
  for _ in $(seq 1 180); do
    if curl -fsS "http://$HOST:$PORT/v1/models" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

wait_for_thinking_log() {
  for _ in $(seq 1 60); do
    if rg -n "chat template, thinking = ${EXPECTED_THINKING_LOG}" "$SERVER_LOG" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

server_args=(
  "$SERVER_BIN"
  --device "$DEVICE"
  --gpu-layers "$GPU_LAYERS"
  --host "$HOST"
  --port "$PORT"
  --model "$MODEL_PATH"
  --alias "$MODEL_NAME"
  --ctx-size "$CTX_SIZE"
  --temp 0.0
  --top-p 1.0
  --top-k 0
  --min-p 0.0
  --presence-penalty 0.0
  --repeat-penalty 1.0
  --flash-attn on
  --cache-type-k q8_0
  --cache-type-v q8_0
  --kv-unified
  --cache-prompt
  --cache-ram "$CACHE_RAM"
  --cache-reuse "$CACHE_REUSE"
  --batch-size "$BATCH_SIZE"
  --ubatch-size "$UBATCH_SIZE"
  --threads-batch "$THREADS_BATCH"
  --threads "$THREADS"
  --parallel 1
  --mlock
  --no-mmap
  --reasoning-format "$SERVER_REASONING_FORMAT"
  --reasoning "$SERVER_REASONING_FLAG"
  --n-predict "$SERVER_MAX_TOKENS"
  --jinja
  --chat-template-kwargs "$CHAT_TEMPLATE_KWARGS_JSON"
)

if [[ "$THINKING_MODE" == "on" && "$REASONING_BUDGET" -ge 0 ]]; then
  server_args+=(--reasoning-budget "$REASONING_BUDGET")
  server_args+=(--reasoning-budget-message "$REASONING_BUDGET_MESSAGE")
fi

"${server_args[@]}" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

if ! wait_for_server; then
  echo "Server failed to become ready. Last log lines:"
  tail -n 120 "$SERVER_LOG" || true
  exit 1
fi

if ! wait_for_thinking_log; then
  echo "Server became ready but did not log thinking = ${EXPECTED_THINKING_LOG}. Last log lines:"
  tail -n 120 "$SERVER_LOG" || true
  exit 1
fi

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
  echo "Server max tokens: $SERVER_MAX_TOKENS"
  echo "Reasoning budget: ${REASONING_BUDGET:-n/a}"
  echo "Server command:"
  printf '  '
  printf '%q ' "${server_args[@]}"
  echo
  echo "Subset env:"
  printf '  %q ' "${env_args[@]}"
  echo
} >"$LAUNCH_LOG"

env "${env_args[@]}" \
  "$SUBSET_SCRIPT" "$MODEL_NAME" | tee "$RUN_LOG"

kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo ""
echo "Run complete."
echo "Run root: $RUN_ROOT"
