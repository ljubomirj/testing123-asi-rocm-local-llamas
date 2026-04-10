#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBSET_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_subset.sh"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-macbook2-metal/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"

MODEL_NAME="${MODEL_NAME:-Nemotron-Cascade-2-30B-A3B-Q6}"
MODEL_PATH="${MODEL_PATH:-$HOME/llama.cpp/models/Nemotron-Cascade-2-30B-A3B.Q6_K.gguf}"

# Match the incumbent LiveCodeBench recipe where it matters for accuracy
# (n=1, temp=0, top_p=1), while reusing the current macbook2 llama.cpp
# cache/thread configuration from the Nemotron wrapper.
#
# Nemotron thinking-mode proved impractical with a 100000-token cap on the
# local subset run: it completed only 1/36 problems in 21 minutes and the
# second request never returned. Use the same 16384-token ceiling already used
# by the local MiroThinker thinking-model subset so the run can finish.
CTX_SIZE="${CTX_SIZE:-150000}"
SERVER_MAX_TOKENS="${SERVER_MAX_TOKENS:-16384}"
MAX_TOKENS="${MAX_TOKENS:-16384}"
OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1800}"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/runs/livecodebench_nemotron_$(date +%Y%m%d_%H%M%S)}"

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
    if rg -n "chat template, thinking = 1" "$SERVER_LOG" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

"$SERVER_BIN" \
  --host "$HOST" \
  --port "$PORT" \
  --model "$MODEL_PATH" \
  --alias "$MODEL_NAME" \
  --ctx-size "$CTX_SIZE" \
  --temp 0.0 \
  --top-p 1.0 \
  --top-k 0 \
  --min-p 0.0 \
  --presence-penalty 0.0 \
  --repeat-penalty 1.0 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --kv-unified \
  --cache-prompt \
  --cache-ram 16384 \
  --cache-reuse 512 \
  --batch-size 2048 \
  --ubatch-size 512 \
  --threads-batch 10 \
  --threads 10 \
  --parallel 1 \
  --mlock \
  --no-mmap \
  --reasoning-format deepseek \
  --reasoning on \
  --n-predict "$SERVER_MAX_TOKENS" \
  --jinja \
  >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

{
  echo "Script: $0"
  echo "Run root: $RUN_ROOT"
  echo "Thinking mode: on"
  echo "Reasoning format: deepseek"
  echo "Reasoning budget: -1"
  echo "Max tokens: $MAX_TOKENS"
  echo "Server max tokens: $SERVER_MAX_TOKENS"
  cat <<EOF
Server command:
  $SERVER_BIN --host $HOST --port $PORT --model $MODEL_PATH --alias $MODEL_NAME --ctx-size $CTX_SIZE --temp 0.0 --top-p 1.0 --top-k 0 --min-p 0.0 --presence-penalty 0.0 --repeat-penalty 1.0 --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 --kv-unified --cache-prompt --cache-ram 16384 --cache-reuse 512 --batch-size 2048 --ubatch-size 512 --threads-batch 10 --threads 10 --parallel 1 --mlock --no-mmap --reasoning-format deepseek --reasoning on --n-predict $SERVER_MAX_TOKENS --jinja
Subset env:
  OPENAI_API_BASE=http://$HOST:$PORT/v1 OPENAI_BASE_URL=http://$HOST:$PORT/v1 OPENAI_TIMEOUT=$OPENAI_TIMEOUT MAX_TOKENS=$MAX_TOKENS TEMP=0.0 TOP_P=1.0 N=1 RESET_OUTPUT=1 LOG_DIR=$RUN_ROOT LCB_REASONING_FORMAT=deepseek
EOF
} >"$LAUNCH_LOG"

if ! wait_for_server; then
  echo "Server failed to become ready. Last log lines:"
  tail -n 120 "$SERVER_LOG" || true
  exit 1
fi

if ! wait_for_thinking_log; then
  echo "Server became ready but did not log thinking = 1. Last log lines:"
  tail -n 120 "$SERVER_LOG" || true
  exit 1
fi

OPENAI_API_BASE="http://$HOST:$PORT/v1" \
OPENAI_BASE_URL="http://$HOST:$PORT/v1" \
OPENAI_TIMEOUT="$OPENAI_TIMEOUT" \
MAX_TOKENS="$MAX_TOKENS" \
TEMP=0.0 \
TOP_P=1.0 \
N=1 \
RESET_OUTPUT=1 \
LOG_DIR="$RUN_ROOT" \
LCB_REASONING_FORMAT="deepseek" \
"$SUBSET_SCRIPT" "$MODEL_NAME" | tee "$RUN_LOG"

kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo ""
echo "Run complete."
echo "Run root: $RUN_ROOT"
