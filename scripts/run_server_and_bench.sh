#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

export TMPDIR="${TMPDIR:-/home/ljubomir/tmp}"
export TMP="${TMP:-/home/ljubomir/tmp}"
export SGLANG_INT8_KV_HIP="${SGLANG_INT8_KV_HIP:-1}"
export SGLANG_INT8_KV_HIP_DEBUG="${SGLANG_INT8_KV_HIP_DEBUG:-1}"
export SGLANG_KILL_EXISTING="${SGLANG_KILL_EXISTING:-1}"

if [[ "${SGLANG_KILL_EXISTING}" == "1" ]]; then
  pkill -f "sglang.launch_server" 2>/dev/null || true
fi

stdbuf -oL -eL ./run_sglang_rocm711.sh |& tee run-server.log &
pid=$!
cleanup() {
  kill "${pid}" 2>/dev/null || true
}
trap cleanup EXIT

for _ in {1..180}; do
  if rg -q "ready to roll" run-server.log; then
    break
  fi
  sleep 1
done

max_tokens_arg=()
if [[ -n "${BENCH_MAX_TOKENS:-}" ]]; then
  max_tokens_arg=(--max-tokens "${BENCH_MAX_TOKENS}")
fi
prompt_len_arg=()
if [[ -n "${BENCH_PROMPT_LEN:-}" ]]; then
  prompt_len_arg=(--prompt-len "${BENCH_PROMPT_LEN}")
fi
prompt_file_arg=()
if [[ -n "${BENCH_PROMPT_FILE:-}" ]]; then
  prompt_file_arg=(--prompt-file "${BENCH_PROMPT_FILE}")
fi
system_file_arg=()
if [[ -n "${BENCH_SYSTEM_FILE:-}" ]]; then
  system_file_arg=(--system-file "${BENCH_SYSTEM_FILE}")
fi
verbose_arg=()
if [[ -n "${BENCH_VERBOSE:-}" ]]; then
  case "${BENCH_VERBOSE}" in
    2) verbose_arg=(-vv) ;;
    1) verbose_arg=(-v) ;;
  esac
fi

python3 bench_sglang.py \
  --base http://127.0.0.1:8000 \
  --model glm-4.7-flash \
  --runs "${RUNS:-3}" \
  "${max_tokens_arg[@]}" \
  "${prompt_len_arg[@]}" \
  "${prompt_file_arg[@]}" \
  "${system_file_arg[@]}" \
  "${verbose_arg[@]}" |& tee run-client.log
