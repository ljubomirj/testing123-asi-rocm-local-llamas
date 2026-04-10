#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MATRIX_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_matrix.sh"
SUBSET_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_subset.sh"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"
DEVICE="${DEVICE:-ROCm0}"

QWEN_TEMPLATE_FILE="${QWEN_TEMPLATE_FILE:-$ROOT_DIR/scripts/qwen3.5_chat_template.jinja}"
QWEN_TEMPLATE_KWARGS="${QWEN_TEMPLATE_KWARGS:-{\"enable_thinking\": false}}"
QWEN_MAX_TOKENS="${QWEN_MAX_TOKENS:-10000}"

GLM_MODEL_PATH="${GLM_MODEL_PATH:-$HOME/llama.cpp/models/GLM-4.7-Flash-UD-Q4_K_XL.gguf}"
GLM_MODEL_NAME="${GLM_MODEL_NAME:-GLM-4.7-Flash-Q4}"
GLM_MAX_TOKENS="${GLM_MAX_TOKENS:-10000}"

OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1200}"
PARALLEL="${PARALLEL:-1}"
BATCH_SIZE="${BATCH_SIZE:-2048}"
UBATCH_SIZE="${UBATCH_SIZE:-512}"
THREADS_BATCH="${THREADS_BATCH:-10}"
THREADS="${THREADS:-10}"

if [[ ! -x "$MATRIX_SCRIPT" ]]; then
  echo "Missing executable script: $MATRIX_SCRIPT"
  exit 1
fi
if [[ ! -x "$SUBSET_SCRIPT" ]]; then
  echo "Missing executable script: $SUBSET_SCRIPT"
  exit 1
fi
if [[ ! -x "$SERVER_BIN" ]]; then
  echo "Missing llama-server binary: $SERVER_BIN"
  exit 1
fi
if [[ ! -f "$QWEN_TEMPLATE_FILE" ]]; then
  echo "Missing Qwen chat template: $QWEN_TEMPLATE_FILE"
  exit 1
fi
if [[ ! -f "$GLM_MODEL_PATH" ]]; then
  echo "Missing GLM model: $GLM_MODEL_PATH"
  exit 1
fi

LATEST_BEFORE="$(ls -1dt "$ROOT_DIR"/benchmark_results_livecodebench_matrix_* 2>/dev/null | head -n 1 || true)"

echo "=== Stage 1/2: Qwen3.5 matrix (template + thinking off) ==="
CHAT_TEMPLATE_FILE="$QWEN_TEMPLATE_FILE" \
CHAT_TEMPLATE_KWARGS="$QWEN_TEMPLATE_KWARGS" \
REASONING_FORMAT=none \
REASONING_BUDGET=0 \
MAX_TOKENS="$QWEN_MAX_TOKENS" \
OPENAI_TIMEOUT="$OPENAI_TIMEOUT" \
HOST="$HOST" \
PORT="$PORT" \
DEVICE="$DEVICE" \
CTX_SIZE=150000 \
CACHE_RAM=32768 \
CACHE_REUSE=512 \
KV_UNIFIED=1 \
USE_MMAP=0 \
PARALLEL="$PARALLEL" \
BATCH_SIZE="$BATCH_SIZE" \
UBATCH_SIZE="$UBATCH_SIZE" \
THREADS_BATCH="$THREADS_BATCH" \
THREADS="$THREADS" \
"$MATRIX_SCRIPT"

QWEN_RESULT_DIR="$(ls -1dt "$ROOT_DIR"/benchmark_results_livecodebench_matrix_* 2>/dev/null | head -n 1 || true)"
if [[ -z "$QWEN_RESULT_DIR" || "$QWEN_RESULT_DIR" == "$LATEST_BEFORE" ]]; then
  echo "Could not identify new Qwen matrix result directory."
  exit 1
fi
echo "Qwen matrix result directory: $QWEN_RESULT_DIR"

echo ""
echo "=== Stage 2/2: GLM-4.7-Flash baseline (no special template, thinking on) ==="

GLM_RESULT_ROOT="$ROOT_DIR/benchmark_results_livecodebench_glm_baseline_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$GLM_RESULT_ROOT"
GLM_SERVER_LOG="$GLM_RESULT_ROOT/${GLM_MODEL_NAME}.server.log"
GLM_RUN_LOG="$GLM_RESULT_ROOT/${GLM_MODEL_NAME}.run.log"

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
  --model "$GLM_MODEL_PATH" \
  --alias "$GLM_MODEL_NAME" \
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
  --parallel "$PARALLEL" \
  --batch-size "$BATCH_SIZE" \
  --ubatch-size "$UBATCH_SIZE" \
  --threads-batch "$THREADS_BATCH" \
  --threads "$THREADS" \
  --mlock \
  --no-mmap \
  --kv-unified \
  --n-predict "$GLM_MAX_TOKENS" \
  >"$GLM_SERVER_LOG" 2>&1 &
SERVER_PID=$!

echo "Started GLM server PID: $SERVER_PID"

for _ in $(seq 1 180); do
  if curl -fsS "http://$HOST:$PORT/v1/models" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
if ! curl -fsS "http://$HOST:$PORT/v1/models" >/dev/null 2>&1; then
  echo "GLM server failed to become ready. Last lines:"
  tail -n 80 "$GLM_SERVER_LOG" || true
  exit 1
fi

OPENAI_API_BASE="http://$HOST:$PORT/v1" \
OPENAI_BASE_URL="http://$HOST:$PORT/v1" \
OPENAI_TIMEOUT="$OPENAI_TIMEOUT" \
MAX_TOKENS="$GLM_MAX_TOKENS" \
TEMP=0.0 \
TOP_P=1.0 \
N=1 \
RESET_OUTPUT=1 \
LOG_DIR="$GLM_RESULT_ROOT" \
"$SUBSET_SCRIPT" "$GLM_MODEL_NAME" | tee "$GLM_RUN_LOG"

kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo ""
echo "Run complete."
echo "Qwen matrix: $QWEN_RESULT_DIR"
echo "GLM baseline: $GLM_RESULT_ROOT"
