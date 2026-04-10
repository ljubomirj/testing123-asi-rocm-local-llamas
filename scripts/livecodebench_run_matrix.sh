#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"
DEVICE="${DEVICE:-ROCm0}"
CTX_SIZE="${CTX_SIZE:-150000}"
MAX_TOKENS="${MAX_TOKENS:-100000}"
CHAT_TEMPLATE_FILE="${CHAT_TEMPLATE_FILE:-}"
CHAT_TEMPLATE_KWARGS="${CHAT_TEMPLATE_KWARGS:-}"
REASONING_FORMAT="${REASONING_FORMAT:-none}"
REASONING_BUDGET="${REASONING_BUDGET:-0}"
CACHE_RAM="${CACHE_RAM:-0}"
CACHE_REUSE="${CACHE_REUSE:-}"
CTX_CHECKPOINTS="${CTX_CHECKPOINTS:-}"
KV_UNIFIED="${KV_UNIFIED:-1}"
SWA_FULL="${SWA_FULL:-0}"
USE_MMAP="${USE_MMAP:-0}"

if [[ -z "$CHAT_TEMPLATE_KWARGS" ]]; then
  CHAT_TEMPLATE_KWARGS='{"enable_thinking": false}'
fi

MODEL_NAMES=(
  "Qwen3.5-35B-A3B-IQ4"
  "Qwen3.5-27B-Q4"
  "Qwen3.5-9B-Q8"
)

MODEL_PATHS=(
  "$HOME/llama.cpp/models/Qwen3.5-35B-A3B-UD-IQ4_XS.gguf"
  "$HOME/llama.cpp/models/Qwen3.5-27B-UD-Q4_K_XL.gguf"
  "$HOME/llama.cpp/models/Qwen3.5-9B-UD-Q8_K_XL.gguf"
)

if [[ ! -x "$SERVER_BIN" ]]; then
  echo "llama-server binary not found or not executable: $SERVER_BIN"
  exit 1
fi

if [[ -n "$CHAT_TEMPLATE_FILE" ]]; then
  if [[ -f "$CHAT_TEMPLATE_FILE" ]]; then
    CHAT_TEMPLATE_FILE="$(realpath "$CHAT_TEMPLATE_FILE")"
  elif [[ -f "$ROOT_DIR/$CHAT_TEMPLATE_FILE" ]]; then
    CHAT_TEMPLATE_FILE="$(realpath "$ROOT_DIR/$CHAT_TEMPLATE_FILE")"
  elif [[ -f "$ROOT_DIR/scripts/$CHAT_TEMPLATE_FILE" ]]; then
    CHAT_TEMPLATE_FILE="$(realpath "$ROOT_DIR/scripts/$CHAT_TEMPLATE_FILE")"
  else
    echo "chat template file not found: $CHAT_TEMPLATE_FILE"
    exit 1
  fi
fi

RESULT_ROOT="$ROOT_DIR/benchmark_results_livecodebench_matrix_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULT_ROOT"
SUMMARY_CSV="$RESULT_ROOT/summary.csv"
echo "model,model_path,total_seconds,problems,problems_per_minute,subset_dir,server_log" > "$SUMMARY_CSV"

SERVER_PID=""
cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_server() {
  local tries=180
  local sleep_s=2
  local url="http://$HOST:$PORT/v1/models"
  for ((i=1; i<=tries; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_s"
  done
  return 1
}

for i in "${!MODEL_NAMES[@]}"; do
  model_name="${MODEL_NAMES[$i]}"
  model_path="${MODEL_PATHS[$i]}"
  model_safe="${model_name//[^A-Za-z0-9._-]/_}"

  if [[ ! -f "$model_path" ]]; then
    echo "Model file missing: $model_path"
    exit 1
  fi

  server_log="$RESULT_ROOT/${model_safe}.server.log"
  run_log="$RESULT_ROOT/${model_safe}.run.log"
  subset_dir="$RESULT_ROOT/${model_safe}_subset"
  mkdir -p "$subset_dir"

  echo ""
  echo "=== Starting server for $model_name ==="
  server_args=(
    "$SERVER_BIN"
    --device "$DEVICE" \
    --gpu-layers all \
    --ctx-size "$CTX_SIZE" \
    --host "$HOST" \
    --port "$PORT" \
    --model "$model_path" \
    --alias "$model_name" \
    --temp "${SERVER_TEMP:-0.0}" \
    --top-p "${SERVER_TOP_P:-1.0}" \
    --top-k "${SERVER_TOP_K:-0}" \
    --min-p "${SERVER_MIN_P:-0.0}" \
    --seed "${SERVER_SEED:-3407}" \
    --presence-penalty "${SERVER_PRESENCE_PENALTY:-0.0}" \
    --repeat-penalty "${SERVER_REPEAT_PENALTY:-1.0}" \
    --flash-attn on \
    --reasoning-format "$REASONING_FORMAT" \
    --reasoning-budget "$REASONING_BUDGET" \
    --chat-template-kwargs "$CHAT_TEMPLATE_KWARGS" \
    --cache-type-k q8_0 \
    --cache-type-v q8_0 \
    --jinja \
    --cache-ram "$CACHE_RAM" \
    --parallel "${PARALLEL:-1}" \
    --batch-size "${BATCH_SIZE:-2048}" \
    --ubatch-size "${UBATCH_SIZE:-512}" \
    --threads-batch "${THREADS_BATCH:-10}" \
    --threads "${THREADS:-10}" \
    --mlock \
    --n-predict "$MAX_TOKENS"
  )
  if [[ "$USE_MMAP" == "1" ]]; then
    server_args+=(--mmap)
  else
    server_args+=(--no-mmap)
  fi
  if [[ "$KV_UNIFIED" == "1" ]]; then
    server_args+=(--kv-unified)
  else
    server_args+=(--no-kv-unified)
  fi
  if [[ "$SWA_FULL" == "1" ]]; then
    server_args+=(--swa-full)
  fi
  if [[ -n "$CTX_CHECKPOINTS" ]]; then
    server_args+=(--ctx-checkpoints "$CTX_CHECKPOINTS")
  fi
  if [[ -n "$CACHE_REUSE" ]]; then
    server_args+=(--cache-reuse "$CACHE_REUSE")
  fi
  if [[ -n "$CHAT_TEMPLATE_FILE" ]]; then
    server_args+=(--chat-template-file "$CHAT_TEMPLATE_FILE")
  fi

  "${server_args[@]}" >"$server_log" 2>&1 &
  SERVER_PID=$!

  if ! wait_for_server; then
    echo "Server failed to become ready for $model_name. Last log lines:"
    tail -n 80 "$server_log" || true
    exit 1
  fi

  echo "=== Running LiveCodeBench subset for $model_name ==="
  model_start=$SECONDS
  OPENAI_API_BASE="http://$HOST:$PORT/v1" \
  OPENAI_BASE_URL="http://$HOST:$PORT/v1" \
  LOG_DIR="$subset_dir" \
  RESET_OUTPUT=1 \
  N="${N:-1}" \
  TEMP="${TEMP:-0.0}" \
  TOP_P="${TOP_P:-1.0}" \
  MAX_TOKENS="$MAX_TOKENS" \
  OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1200}" \
  "$ROOT_DIR/scripts/livecodebench_run_subset.sh" "$model_name" \
    | tee "$run_log"
  model_elapsed=$((SECONDS - model_start))

  problems=92
  ppm="$(awk -v p="$problems" -v s="$model_elapsed" 'BEGIN { if (s == 0) printf "0.00"; else printf "%.2f", (p * 60.0) / s; }')"
  echo "${model_name},${model_path},${model_elapsed},${problems},${ppm},${subset_dir},${server_log}" >> "$SUMMARY_CSV"

  kill "$SERVER_PID" >/dev/null 2>&1 || true
  wait "$SERVER_PID" 2>/dev/null || true
  SERVER_PID=""
done

echo ""
echo "Matrix run complete."
echo "Summary: $SUMMARY_CSV"
