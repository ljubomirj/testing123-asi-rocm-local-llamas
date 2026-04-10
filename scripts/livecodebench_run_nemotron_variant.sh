#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBSET_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_subset.sh"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-macbook2-metal/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"

MODEL_NAME="${MODEL_NAME:-Nemotron-Cascade-2-30B-A3B-Q6}"
MODEL_PATH="${MODEL_PATH:-$HOME/llama.cpp/models/Nemotron-Cascade-2-30B-A3B.Q6_K.gguf}"
RUN_LABEL="${RUN_LABEL:-nemotron_variant}"

CTX_SIZE="${CTX_SIZE:-150000}"
MAX_TOKENS="${MAX_TOKENS:-4096}"
SERVER_MAX_TOKENS="${SERVER_MAX_TOKENS:-$MAX_TOKENS}"
OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1800}"

TEMP="${TEMP:-0.0}"
TOP_P="${TOP_P:-1.0}"
TOP_K="${TOP_K:-0}"
MIN_P="${MIN_P:-0.0}"
PRESENCE_PENALTY="${PRESENCE_PENALTY:-0.0}"
REPEAT_PENALTY="${REPEAT_PENALTY:-1.0}"
USE_MMAP="${USE_MMAP:-0}"

THINKING_MODE="${THINKING_MODE:-on}"             # on|off
REASONING_FORMAT="${REASONING_FORMAT:-deepseek}" # deepseek|none|auto
REASONING_BUDGET="${REASONING_BUDGET:--1}"       # -1 disables budget
REASONING_BUDGET_MESSAGE="${REASONING_BUDGET_MESSAGE:-Thinking budget exhausted. Stop thinking and provide the best final answer now.}"

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
    SERVER_REASONING_FLAG="on"
    ;;
  off)
    SERVER_REASONING_FLAG="off"
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
  local expected="$1"
  for _ in $(seq 1 60); do
    if rg -n "chat template, thinking = ${expected}" "$SERVER_LOG" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

server_args=(
  "$SERVER_BIN"
  --host "$HOST"
  --port "$PORT"
  --model "$MODEL_PATH"
  --alias "$MODEL_NAME"
  --ctx-size "$CTX_SIZE"
  --temp "$TEMP"
  --top-p "$TOP_P"
  --top-k "$TOP_K"
  --min-p "$MIN_P"
  --presence-penalty "$PRESENCE_PENALTY"
  --repeat-penalty "$REPEAT_PENALTY"
  --flash-attn on
  --cache-type-k q8_0
  --cache-type-v q8_0
  --kv-unified
  --cache-prompt
  --cache-ram 16384
  --cache-reuse 512
  --batch-size 2048
  --ubatch-size 512
  --threads-batch 10
  --threads 10
  --parallel 1
  --mlock
  --reasoning-format "$REASONING_FORMAT"
  --reasoning "$SERVER_REASONING_FLAG"
  --n-predict "$SERVER_MAX_TOKENS"
  --jinja
)

if [[ "$USE_MMAP" == "1" ]]; then
  server_args+=(--mmap)
else
  server_args+=(--no-mmap)
fi

if [[ "$REASONING_BUDGET" -ge 0 ]]; then
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

if [[ "$THINKING_MODE" == "on" ]]; then
  if ! wait_for_thinking_log 1; then
    echo "Server became ready but did not log thinking = 1. Last log lines:"
    tail -n 120 "$SERVER_LOG" || true
    exit 1
  fi
else
  if ! wait_for_thinking_log 0; then
    echo "Server became ready but did not log thinking = 0. Last log lines:"
    tail -n 120 "$SERVER_LOG" || true
    exit 1
  fi
fi

env_args=(
  "OPENAI_API_BASE=http://$HOST:$PORT/v1"
  "OPENAI_BASE_URL=http://$HOST:$PORT/v1"
  "OPENAI_TIMEOUT=$OPENAI_TIMEOUT"
  "MAX_TOKENS=$MAX_TOKENS"
  "TEMP=$TEMP"
  "TOP_P=$TOP_P"
  "N=1"
  "RESET_OUTPUT=1"
  "LOG_DIR=$RUN_ROOT"
)

if [[ "$THINKING_MODE" == "on" ]]; then
  env_args+=("LCB_REASONING_FORMAT=$REASONING_FORMAT")
fi

{
  echo "Script: $0"
  echo "Run root: $RUN_ROOT"
  echo "Thinking mode: $THINKING_MODE"
  echo "Reasoning format: $REASONING_FORMAT"
  echo "Reasoning budget: $REASONING_BUDGET"
  echo "Max tokens: $MAX_TOKENS"
  echo "Server max tokens: $SERVER_MAX_TOKENS"
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
