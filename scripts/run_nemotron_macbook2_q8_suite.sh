#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUITE_ROOT="${SUITE_ROOT:-$ROOT_DIR/runs/nemotron_macbook2_q8_suite_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$SUITE_ROOT"

CONTEXT_SCRIPT="$ROOT_DIR/scripts/run_nemotron_context_suite_macbook2.sh"
LCB_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_nemotron_variant.sh"
SUITE_LOG="$SUITE_ROOT/suite.log"

{
  echo "Script: $0"
  echo "Suite root: $SUITE_ROOT"
  echo "Started: $(date -Iseconds)"
} >"$SUITE_LOG"

echo "=== Context suite ===" | tee -a "$SUITE_LOG"
RUN_ROOT="$SUITE_ROOT/context" \
MODEL_PATH="$HOME/llama.cpp/models/Nemotron-Cascade-2-30B-A3B-Q8_0.gguf" \
MODEL_ALIAS="nemotron-cascade-2-30b-a3b-q8" \
"$CONTEXT_SCRIPT" | tee -a "$SUITE_LOG"

echo "" | tee -a "$SUITE_LOG"
echo "=== LiveCodeBench: thinking ON, budget 8192 / total 16384 ===" | tee -a "$SUITE_LOG"
RUN_ROOT="$SUITE_ROOT/livecodebench_on_budget8k_total16k" \
MODEL_NAME="Nemotron-Cascade-2-30B-A3B-Q8" \
MODEL_PATH="$HOME/llama.cpp/models/Nemotron-Cascade-2-30B-A3B-Q8_0.gguf" \
RUN_LABEL="nemotron_macbook2_q8_on_budget8k_total16k" \
CTX_SIZE=1048576 \
THINKING_MODE=on \
MAX_TOKENS=16384 \
SERVER_MAX_TOKENS=16384 \
REASONING_BUDGET=8192 \
TEMP=1.0 \
TOP_P=0.95 \
TOP_K=0 \
MIN_P=0.0 \
PRESENCE_PENALTY=0.0 \
REPEAT_PENALTY=1.0 \
USE_MMAP=1 \
"$LCB_SCRIPT" | tee -a "$SUITE_LOG"

echo "" | tee -a "$SUITE_LOG"
echo "Suite complete: $SUITE_ROOT" | tee -a "$SUITE_LOG"
