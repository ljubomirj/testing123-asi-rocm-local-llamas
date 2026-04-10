#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_SCRIPT="$ROOT_DIR/bench_longcontext_macbook.py"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-macbook2-metal/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"

MODEL_PATH="${MODEL_PATH:-$HOME/llama.cpp/models/Nemotron-Cascade-2-30B-A3B-Q8_0.gguf}"
MODEL_ALIAS="${MODEL_ALIAS:-nemotron-cascade-2-30b-a3b-q8}"

CTX_SIZE="${CTX_SIZE:-1048576}"
RUNS="${RUNS:-3}"

CACHE_RAM="${CACHE_RAM:-16384}"
CACHE_REUSE="${CACHE_REUSE:-512}"
BATCH_SIZE="${BATCH_SIZE:-2048}"
UBATCH_SIZE="${UBATCH_SIZE:-512}"
THREADS_BATCH="${THREADS_BATCH:-10}"
THREADS="${THREADS:-10}"

TEMP="${TEMP:-1.0}"
TOP_P="${TOP_P:-0.95}"
TOP_K="${TOP_K:-0}"
MIN_P="${MIN_P:-0.0}"
PRESENCE_PENALTY="${PRESENCE_PENALTY:-0.0}"
REPEAT_PENALTY="${REPEAT_PENALTY:-1.0}"

SERVER_MAX_TOKENS="${SERVER_MAX_TOKENS:-16384}"
REASONING_BUDGET="${REASONING_BUDGET:-8192}"
REASONING_BUDGET_MESSAGE="${REASONING_BUDGET_MESSAGE:-Thinking budget exhausted. Stop thinking and provide the best final answer now.}"

NONE_MAX_TOKENS="${NONE_MAX_TOKENS:-200}"
CONTEXT_MAX_TOKENS="${CONTEXT_MAX_TOKENS:-512}"

RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/runs/nemotron_macbook2_q8_context_$(date +%Y%m%d_%H%M%S)}"
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
  for _ in $(seq 1 60); do
    if rg -n "chat template, thinking = 1" "$SERVER_LOG" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

start_server() {
  SERVER_LOG="$RUN_ROOT/llama-server-thinking-on.log"
  local -a server_args=(
    "$SERVER_BIN"
    --host "$HOST"
    --port "$PORT"
    --model "$MODEL_PATH"
    --alias "$MODEL_ALIAS"
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
    --cache-ram "$CACHE_RAM"
    --cache-reuse "$CACHE_REUSE"
    --batch-size "$BATCH_SIZE"
    --ubatch-size "$UBATCH_SIZE"
    --threads-batch "$THREADS_BATCH"
    --threads "$THREADS"
    --parallel 1
    --mlock
    --mmap
    --n-predict "$SERVER_MAX_TOKENS"
    --reasoning on
    --reasoning-format deepseek
    --reasoning-budget "$REASONING_BUDGET"
    --reasoning-budget-message "$REASONING_BUDGET_MESSAGE"
    --jinja
  )

  "${server_args[@]}" >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!

  if ! wait_for_server; then
    echo "Server failed to become ready. Last log lines:"
    tail -n 120 "$SERVER_LOG" || true
    exit 1
  fi
  if ! wait_for_thinking_log; then
    echo "Server became ready but did not log thinking = 1."
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
  local label="$1"
  local prefill_tokens="$2"
  local prompt_tokens="$3"
  local max_tokens="$4"
  local output_file="$5"
  local backend_label="$6"

  local -a args=(
    python3
    "$BENCH_SCRIPT"
    --base "http://$HOST:$PORT"
    --model "$MODEL_ALIAS"
    --runs "$RUNS"
    --max-tokens "$max_tokens"
    --output "$output_file"
    --backend-label "$backend_label"
    --prompt-tokens "$prompt_tokens"
  )

  if [[ "$label" == "none" ]]; then
    args+=(--no-prefill)
  else
    args+=(--prefill-tokens "$prefill_tokens")
  fi

  printf '\n=== thinking-on / %s ===\n' "$label" | tee -a "$BENCHMARK_LOG"
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
  echo "Server max tokens: $SERVER_MAX_TOKENS"
  echo "Reasoning budget: $REASONING_BUDGET"
} >"$BENCHMARK_LOG"

start_server

BACKEND="llamacpp-metal-wrapper-10t-nemotron-q8-thinking-on"
SUFFIX="_thinking_on"

run_case "none" 0 "50,100" "$NONE_MAX_TOKENS" \
  "$RUN_ROOT/benchmark_nemotron_cascade_2_30b_q8_none_wrapper_10t${SUFFIX}.jsonl" \
  "$BACKEND"
run_case "small" 5000 "10000,15000" "$CONTEXT_MAX_TOKENS" \
  "$RUN_ROOT/benchmark_nemotron_cascade_2_30b_q8_small_5k_wrapper_10t${SUFFIX}.jsonl" \
  "$BACKEND"
run_case "mid" 20000 "10000,15000" "$CONTEXT_MAX_TOKENS" \
  "$RUN_ROOT/benchmark_nemotron_cascade_2_30b_q8_mid_20k_wrapper_10t${SUFFIX}.jsonl" \
  "$BACKEND"
run_case "long" 40000 "10000,15000" "$CONTEXT_MAX_TOKENS" \
  "$RUN_ROOT/benchmark_nemotron_cascade_2_30b_q8_long_wrapper_10t${SUFFIX}.jsonl" \
  "$BACKEND"
run_case "longlong" 100000 "10000,15000" "$CONTEXT_MAX_TOKENS" \
  "$RUN_ROOT/benchmark_nemotron_cascade_2_30b_q8_longlong_100k_wrapper_10t${SUFFIX}.jsonl" \
  "$BACKEND"

stop_server

echo ""
echo "Context suite complete."
echo "Run root: $RUN_ROOT"
