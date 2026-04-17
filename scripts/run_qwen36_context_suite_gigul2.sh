#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_SCRIPT="$ROOT_DIR/scripts/bench_longcontext_macbook.py"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"
DEVICE="${DEVICE:-ROCm0}"
GPU_LAYERS="${GPU_LAYERS:-all}"

MODEL_PATH="${MODEL_PATH:-$HOME/llama.cpp/models/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf}"
MODEL_ALIAS="${MODEL_ALIAS:-qwen3.6-35b-a3b}"

CTX_SIZE="${CTX_SIZE:-150000}"
RUNS="${RUNS:-3}"

CACHE_RAM="${CACHE_RAM:-16384}"
CACHE_REUSE="${CACHE_REUSE:-512}"
BATCH_SIZE="${BATCH_SIZE:-2048}"
UBATCH_SIZE="${UBATCH_SIZE:-512}"
THREADS_BATCH="${THREADS_BATCH:-10}"
THREADS="${THREADS:-8}"

# Qwen3.6 recommended: temp=1.0, top_p=0.95, top_k=20, presence_penalty=1.5
SERVER_TEMP="${SERVER_TEMP:-1.0}"
SERVER_TOP_P="${SERVER_TOP_P:-0.95}"
SERVER_TOP_K="${SERVER_TOP_K:-20}"
SERVER_PRESENCE_PENALTY="${SERVER_PRESENCE_PENALTY:-1.5}"
SERVER_REPEAT_PENALTY="${SERVER_REPEAT_PENALTY:-1.0}"

NONE_MAX_TOKENS="${NONE_MAX_TOKENS:-200}"
CONTEXT_MAX_TOKENS="${CONTEXT_MAX_TOKENS:-512}"

RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/runs/qwen36_gigul2_context_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$RUN_ROOT"

if [[ ! -x "$SERVER_BIN" ]]; then
  echo "Missing llama-server binary: $SERVER_BIN"
  exit 1
fi
if [[ ! -f "$MODEL_PATH" ]]; then
  echo "Missing model file: $MODEL_PATH"
  exit 1
fi
if [[ ! -f "$BENCH_SCRIPT" ]]; then
  echo "Missing benchmark script: $BENCH_SCRIPT"
  exit 1
fi

SERVER_PID=""
SERVER_LOG=""
BENCHMARK_LOG="$RUN_ROOT/benchmark_runner.log"

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_server() {
  for _ in $(seq 1 180); do
    if curl -fsS "http://$HOST:$PORT/health" >/dev/null 2>&1; then
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

start_server() {
  local mode="$1"
  local reasoning_format reasoning_flag expected chat_kwargs_json

  case "$mode" in
    off)
      reasoning_format="none"
      reasoning_flag="off"
      expected="0"
      chat_kwargs_json='{"enable_thinking":false}'
      ;;
    on)
      reasoning_format="deepseek"
      reasoning_flag="on"
      expected="1"
      chat_kwargs_json='{"enable_thinking":true}'
      ;;
    *)
      echo "Unknown mode: $mode"
      exit 1
      ;;
  esac

  SERVER_LOG="$RUN_ROOT/llama-server-${mode}.log"
  local -a server_args=(
    "$SERVER_BIN"
    --device "$DEVICE"
    --gpu-layers "$GPU_LAYERS"
    --host "$HOST"
    --port "$PORT"
    --model "$MODEL_PATH"
    --alias "$MODEL_ALIAS"
    --ctx-size "$CTX_SIZE"
    --temp "$SERVER_TEMP"
    --top-p "$SERVER_TOP_P"
    --top-k "$SERVER_TOP_K"
    --min-p 0.0
    --presence-penalty "$SERVER_PRESENCE_PENALTY"
    --repeat-penalty "$SERVER_REPEAT_PENALTY"
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
    --reasoning-format "$reasoning_format"
    --reasoning "$reasoning_flag"
    --n-predict 10000
    --jinja
    --chat-template-kwargs "$chat_kwargs_json"
  )

  "${server_args[@]}" >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!

  if ! wait_for_server; then
    echo "Server failed to become ready for mode $mode. Last log lines:"
    tail -n 120 "$SERVER_LOG" || true
    exit 1
  fi
  if ! wait_for_thinking_log "$expected"; then
    echo "Server became ready but did not log thinking = $expected for mode $mode."
    tail -n 120 "$SERVER_LOG" || true
    exit 1
  fi
}

stop_server() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  SERVER_PID=""
}

run_case() {
  local mode="$1"
  local label="$2"
  local prefill_tokens="$3"
  local prompt_tokens="$4"
  local max_tokens="$5"
  local output_file="$6"
  local backend_label="$7"

  local -a args=(
    python3
    "$BENCH_SCRIPT"
    --base "http://$HOST:$PORT"
    --model "$MODEL_ALIAS"
    --runs "$RUNS"
    --max-tokens "$max_tokens"
    --output "$output_file"
    --backend-label "$backend_label"
  )

  if [[ "$label" == "none" ]]; then
    args+=(--no-prefill)
  else
    args+=(--prefill-tokens "$prefill_tokens")
  fi
  args+=(--prompt-tokens "$prompt_tokens")

  if [[ "$mode" == "off" ]]; then
    args+=(--assistant-prefill 'ဿ')
    args+=(--chat-template-kwargs-json '{"enable_thinking": false}')
  fi

  printf '\n=== %s / %s ===\n' "$mode" "$label" | tee -a "$BENCHMARK_LOG"
  printf 'Command: ' | tee -a "$BENCHMARK_LOG"
  printf '%q ' "${args[@]}" | tee -a "$BENCHMARK_LOG"
  printf '\n' | tee -a "$BENCHMARK_LOG"
  "${args[@]}" | tee -a "$BENCHMARK_LOG"
}

{
  echo "Script: $0"
  echo "Run root: $RUN_ROOT"
  echo "Model path: $MODEL_PATH"
  echo "Server bin: $SERVER_BIN"
  echo "Host: $HOST:$PORT"
  echo "Ctx size: $CTX_SIZE"
  echo "Runs per case: $RUNS"
  echo "Sampling: temp=$SERVER_TEMP top_p=$SERVER_TOP_P top_k=$SERVER_TOP_K presence_penalty=$SERVER_PRESENCE_PENALTY"
  echo "Cache RAM: $CACHE_RAM"
  echo "Cache reuse: $CACHE_REUSE"
  echo "Batch: $BATCH_SIZE / $UBATCH_SIZE"
  echo "Threads: $THREADS / $THREADS_BATCH"
} >"$BENCHMARK_LOG"

for mode in off on; do
  start_server "$mode"
  if [[ "$mode" == "off" ]]; then
    backend="llamacpp-hip-rocwmma-qwen36-35b-a3b-iq4xs"
    suffix=""
  else
    backend="llamacpp-hip-rocwmma-qwen36-35b-a3b-iq4xs-thinking-on"
    suffix="_thinking_on"
  fi

  run_case "$mode" "none" 0 "50,100" "$NONE_MAX_TOKENS" \
    "$RUN_ROOT/benchmark_qwen36_35b_a3b_iq4_xs_none${suffix}.jsonl" \
    "$backend"
  run_case "$mode" "small" 5000 "10000,15000" "$CONTEXT_MAX_TOKENS" \
    "$RUN_ROOT/benchmark_qwen36_35b_a3b_iq4_xs_small_5k${suffix}.jsonl" \
    "$backend"
  run_case "$mode" "mid" 20000 "10000,15000" "$CONTEXT_MAX_TOKENS" \
    "$RUN_ROOT/benchmark_qwen36_35b_a3b_iq4_xs_mid_20k${suffix}.jsonl" \
    "$backend"
  run_case "$mode" "long" 40000 "10000,15000" "$CONTEXT_MAX_TOKENS" \
    "$RUN_ROOT/benchmark_qwen36_35b_a3b_iq4_xs_long_40k${suffix}.jsonl" \
    "$backend"
  run_case "$mode" "longlong" 100000 "10000,15000" "$CONTEXT_MAX_TOKENS" \
    "$RUN_ROOT/benchmark_qwen36_35b_a3b_iq4_xs_longlong_100k${suffix}.jsonl" \
    "$backend"

  stop_server
done

echo ""
echo "Context suite complete."
echo "Run root: $RUN_ROOT"
