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

OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1200}"
FULL_MAX_TOKENS="${FULL_MAX_TOKENS:-10000}"
PILOT_MAX_TOKENS="${PILOT_MAX_TOKENS:-100000}"
PILOT_QUOTAS="${PILOT_QUOTAS:-3,4,3}"

BASELINE_GLM_SUBDIR="${BASELINE_GLM_SUBDIR:-}"
if [[ -z "$BASELINE_GLM_SUBDIR" ]]; then
  BASELINE_ROOT="$(ls -1dt "$ROOT_DIR"/benchmark_results_livecodebench_glm_baseline_* 2>/dev/null | head -n1 || true)"
  BASELINE_GLM_SUBDIR="${BASELINE_ROOT:+$BASELINE_ROOT/$MODEL_NAME}"
fi

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
if [[ -z "$BASELINE_GLM_SUBDIR" || ! -d "$BASELINE_GLM_SUBDIR" ]]; then
  echo "Baseline GLM directory not found: $BASELINE_GLM_SUBDIR"
  exit 1
fi

RUN_TS="$(date +%Y%m%d_%H%M%S)"
FULL_ROOT="$ROOT_DIR/benchmark_results_livecodebench_glm_thinking_off_$RUN_TS"
PILOT_ROOT="$ROOT_DIR/benchmark_results_livecodebench_glm_thinking_on_pilot_$RUN_TS"
mkdir -p "$FULL_ROOT" "$PILOT_ROOT"

FULL_SERVER_LOG="$FULL_ROOT/${MODEL_NAME}.server.log"
FULL_RUN_LOG="$FULL_ROOT/${MODEL_NAME}.run.log"
PILOT_SERVER_LOG="$PILOT_ROOT/${MODEL_NAME}.server.log"
PILOT_RUN_LOG="$PILOT_ROOT/${MODEL_NAME}.run.log"
PILOT_IDS_FILE="$PILOT_ROOT/pilot_question_ids.txt"

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

start_server() {
  local server_log="$1"
  shift
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
    "$@" \
    >"$server_log" 2>&1 &
  SERVER_PID=$!
  if ! wait_for_server; then
    echo "Server failed to become ready. Last log lines:"
    tail -n 120 "$server_log" || true
    exit 1
  fi
}

echo "Selecting pilot question IDs from baseline empty outputs:"
echo "  baseline: $BASELINE_GLM_SUBDIR"
echo "  quotas:   $PILOT_QUOTAS"
PILOT_IDS="$(
python3 - "$BASELINE_GLM_SUBDIR" "$PILOT_QUOTAS" <<'PY'
import json
import os
import sys

baseline_dir = sys.argv[1]
quotas = [int(x) for x in sys.argv[2].split(",")]
if len(quotas) != 3:
    raise SystemExit("PILOT_QUOTAS must be 3 comma-separated ints, e.g. 3,4,3")

files = [
    "eval_all_2024-01-01_to_2024-02-29.json",
    "eval_all_2024-05-01_to_2024-06-30.json",
    "eval_all_2025-04-01_to_2025-05-31.json",
]

selected = []
for fname, quota in zip(files, quotas):
    path = os.path.join(baseline_dir, fname)
    rows = json.load(open(path, "r"))
    empties = [
        r["question_id"]
        for r in rows
        if not ((r.get("output_list") or [""])[0] or "").strip()
    ]
    selected.extend(empties[:quota])

selected = list(dict.fromkeys(selected))
print(",".join(selected))
PY
)"

if [[ -z "$PILOT_IDS" ]]; then
  echo "No pilot IDs selected from baseline empties."
  exit 1
fi
{
  echo "$PILOT_IDS" | tr ',' '\n'
} > "$PILOT_IDS_FILE"
echo "Selected $(wc -l < "$PILOT_IDS_FILE") pilot IDs."
echo "Pilot IDs saved: $PILOT_IDS_FILE"

echo
echo "=== Stage 1/2: GLM full subset with thinking OFF ==="
start_server "$FULL_SERVER_LOG" \
  --reasoning-format none \
  --reasoning-budget 0 \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --n-predict "$FULL_MAX_TOKENS"

OPENAI_API_BASE="http://$HOST:$PORT/v1" \
OPENAI_BASE_URL="http://$HOST:$PORT/v1" \
OPENAI_TIMEOUT="$OPENAI_TIMEOUT" \
MAX_TOKENS="$FULL_MAX_TOKENS" \
TEMP=0.0 \
TOP_P=1.0 \
N=1 \
RESET_OUTPUT=1 \
LOG_DIR="$FULL_ROOT" \
"$SUBSET_SCRIPT" "$MODEL_NAME" | tee "$FULL_RUN_LOG"

kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo
echo "=== Stage 2/2: GLM thinking ON + high max_tokens pilot on prior-empty IDs ==="
start_server "$PILOT_SERVER_LOG" \
  --n-predict "$PILOT_MAX_TOKENS"

OPENAI_API_BASE="http://$HOST:$PORT/v1" \
OPENAI_BASE_URL="http://$HOST:$PORT/v1" \
OPENAI_TIMEOUT="$OPENAI_TIMEOUT" \
MAX_TOKENS="$PILOT_MAX_TOKENS" \
TEMP=0.0 \
TOP_P=1.0 \
N=1 \
RESET_OUTPUT=1 \
LOG_DIR="$PILOT_ROOT" \
LCB_INCLUDE_QUESTION_IDS="$PILOT_IDS" \
"$SUBSET_SCRIPT" "$MODEL_NAME" | tee "$PILOT_RUN_LOG"

kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo
echo "Follow-up runs complete."
echo "Full thinking-off root: $FULL_ROOT"
echo "Pilot thinking-on root: $PILOT_ROOT"
echo "Pilot IDs file: $PILOT_IDS_FILE"
