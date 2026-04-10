#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBSET_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_subset.sh"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"
DEVICE="${DEVICE:-ROCm0}"

MODEL_NAME="${MODEL_NAME:-GLM-4.7-Flash-Q4}"
MODEL_PATH="${MODEL_PATH:-$HOME/llama.cpp/models/GLM-4.7-Flash-UD-Q4_K_XL.gguf}"

PILOT_IDS="${PILOT_IDS:-3228,3384,3777}"
PILOT_MAX_TOKENS="${PILOT_MAX_TOKENS:-30000}"
OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1200}"

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
if [[ -z "$PILOT_IDS" ]]; then
  echo "PILOT_IDS is empty."
  exit 1
fi

RUN_ROOT="$ROOT_DIR/benchmark_results_livecodebench_glm_thinking_on_pilot30k_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RUN_ROOT"
SERVER_LOG="$RUN_ROOT/${MODEL_NAME}.server.log"
RUN_LOG="$RUN_ROOT/${MODEL_NAME}.run.log"
IDS_FILE="$RUN_ROOT/pilot_question_ids.txt"
echo "$PILOT_IDS" | tr ',' '\n' > "$IDS_FILE"

SERVER_PID=""
cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

"$SERVER_BIN" \
  --device "$DEVICE" \
  --gpu-layers all \
  --ctx-size 130000 \
  --host "$HOST" \
  --port "$PORT" \
  --model "$MODEL_PATH" \
  --alias "$MODEL_NAME" \
  --temp 1.0 \
  --top-p 0.95 \
  --min-p 0.01 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --jinja \
  --cache-ram 32768 \
  --cache-reuse 512 \
  --cache-prompt \
  --parallel 1 \
  --batch-size 2048 \
  --ubatch-size 512 \
  --threads-batch 10 \
  --threads 10 \
  --mlock \
  --no-mmap \
  --kv-unified \
  --n-predict "$PILOT_MAX_TOKENS" \
  >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 180); do
  if curl -fsS "http://$HOST:$PORT/v1/models" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
if ! curl -fsS "http://$HOST:$PORT/v1/models" >/dev/null 2>&1; then
  echo "Server failed to become ready. Last log lines:"
  tail -n 120 "$SERVER_LOG" || true
  exit 1
fi

OPENAI_API_BASE="http://$HOST:$PORT/v1" \
OPENAI_BASE_URL="http://$HOST:$PORT/v1" \
OPENAI_TIMEOUT="$OPENAI_TIMEOUT" \
MAX_TOKENS="$PILOT_MAX_TOKENS" \
TEMP=0.0 \
TOP_P=1.0 \
N=1 \
RESET_OUTPUT=1 \
LOG_DIR="$RUN_ROOT" \
LCB_INCLUDE_QUESTION_IDS="$PILOT_IDS" \
"$SUBSET_SCRIPT" "$MODEL_NAME" | tee "$RUN_LOG"

kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo ""
echo "Pilot run complete."
echo "Run root: $RUN_ROOT"
echo "Pilot IDs file: $IDS_FILE"
