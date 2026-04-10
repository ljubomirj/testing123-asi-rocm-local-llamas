#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUITE_ROOT="${SUITE_ROOT:-$ROOT_DIR/runs/nemotron_gigul2_suite_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$SUITE_ROOT"

CONTEXT_SCRIPT="$ROOT_DIR/scripts/run_nemotron_context_suite_gigul2.sh"
LCB_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_nemotron_gigul2.sh"
SUITE_LOG="$SUITE_ROOT/suite.log"

{
  echo "Script: $0"
  echo "Suite root: $SUITE_ROOT"
  echo "Started: $(date --iso-8601=seconds)"
} >"$SUITE_LOG"

echo "=== Context suite ===" | tee -a "$SUITE_LOG"
RUN_ROOT="$SUITE_ROOT/context" \
  "$CONTEXT_SCRIPT" | tee -a "$SUITE_LOG"

echo "" | tee -a "$SUITE_LOG"
echo "=== LiveCodeBench: thinking OFF ===" | tee -a "$SUITE_LOG"
RUN_ROOT="$SUITE_ROOT/livecodebench_off" \
THINKING_MODE=off \
MAX_TOKENS=10000 \
SERVER_MAX_TOKENS=10000 \
  "$LCB_SCRIPT" | tee -a "$SUITE_LOG"

echo "" | tee -a "$SUITE_LOG"
echo "=== LiveCodeBench: thinking ON, budget 5000 / total 10000 ===" | tee -a "$SUITE_LOG"
RUN_ROOT="$SUITE_ROOT/livecodebench_on_budget5k_total10k" \
THINKING_MODE=on \
MAX_TOKENS=10000 \
SERVER_MAX_TOKENS=10000 \
REASONING_BUDGET=5000 \
  "$LCB_SCRIPT" | tee -a "$SUITE_LOG"

echo "" | tee -a "$SUITE_LOG"
echo "Suite complete: $SUITE_ROOT" | tee -a "$SUITE_LOG"
