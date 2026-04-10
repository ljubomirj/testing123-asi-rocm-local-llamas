#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBSET_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_subset.sh"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"
DEVICE="${DEVICE:-ROCm0}"

MODEL_NAME="${MODEL_NAME:-MiroThinker-1.7-mini-Q4}"
MODEL_PATH="${MODEL_PATH:-$HOME/llama.cpp/models/MiroThinker-1.7-mini.i1-Q4_K_S.gguf}"

CTX_SIZE="${CTX_SIZE:-65536}"
MAX_TOKENS="${MAX_TOKENS:-16384}"
OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1800}"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/benchmark_results_livecodebench_mirothinker_$(date +%Y%m%d_%H%M%S)}"

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

"$SERVER_BIN" \
  --device "$DEVICE" \
  --gpu-layers all \
  --host "$HOST" \
  --port "$PORT" \
  --model "$MODEL_PATH" \
  --alias "$MODEL_NAME" \
  --ctx-size "$CTX_SIZE" \
  --temp 1.0 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0 \
  --presence-penalty 0.0 \
  --repeat-penalty 1.05 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --kv-unified \
  --cache-prompt \
  --cache-ram 16384 \
  --parallel 1 \
  --batch-size 2048 \
  --ubatch-size 512 \
  --threads-batch 10 \
  --threads 10 \
  --mlock \
  --no-mmap \
  --reasoning on \
  --reasoning-format auto \
  --reasoning-budget -1 \
  --n-predict "$MAX_TOKENS" \
  --jinja \
  >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

if ! wait_for_server; then
  echo "Server failed to become ready. Last log lines:"
  tail -n 120 "$SERVER_LOG" || true
  exit 1
fi

OPENAI_API_BASE="http://$HOST:$PORT/v1" \
OPENAI_BASE_URL="http://$HOST:$PORT/v1" \
OPENAI_TIMEOUT="$OPENAI_TIMEOUT" \
MAX_TOKENS="$MAX_TOKENS" \
TEMP=1.0 \
TOP_P=0.95 \
N=1 \
RESET_OUTPUT=1 \
LOG_DIR="$RUN_ROOT" \
"$SUBSET_SCRIPT" "$MODEL_NAME" | tee "$RUN_LOG"

kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo ""
echo "Run complete."
echo "Run root: $RUN_ROOT"
