#!/bin/bash
# llama-server watchdog wrapper for Qwen3.5-27B with speculative decoding
# Uses Qwen3.5-0.8B as draft model for faster inference
# Author: Claude Code for LJ
# Created: 2026-03-05

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Script configuration
SCRIPT_NAME=$(basename "$0" .sh)
LLAMA_CPP_DIR="$HOME/llama.cpp"
cd "$LLAMA_CPP_DIR" || { echo "ERROR: Cannot cd to $LLAMA_CPP_DIR"; exit 1; }

# Server configuration
SERVER_BIN="./build-gigul2-hip-rocwmma/bin/llama-server"
SERVER_HOST="192.168.1.251"
SERVER_PORT="8081"
MODEL_PATH="$HOME/llama.cpp/models/Qwen3.5-27B-UD-Q4_K_XL.gguf"
MODEL_DRAFT_PATH="$HOME/llama.cpp/models/Qwen3.5-0.8B-UD-Q4_K_XL.gguf"

# Health check interval (seconds)
HEALTH_CHECK_INTERVAL=300

# Server command arguments (with draft model for speculative decoding)
SERVER_ARGS=(
  --device ROCm0
  --gpu-layers all
  --ctx-size 130000
  --host "$SERVER_HOST"
  --port "$SERVER_PORT"
  --model "$MODEL_PATH"
  --model-draft "$MODEL_DRAFT_PATH"
  --cache-type-k q8_0
  --cache-type-v q8_0
  --cache-type-k-draft q8_0
  --cache-type-v-draft q8_0
  --temp 1.0
  --top-p 0.95
  --min-p 0.01
  --flash-attn on
  --jinja
  --cache-ram 32768
  --cache-reuse 512
  --cache-prompt
  --batch-size 2048
  --ubatch-size 512
  --threads-batch 10
  --threads 10
  --mlock
  --no-mmap
  --kv-unified
)

# ==============================================================================
# LOGGING SETUP
# ==============================================================================

LOG_FILE="$LLAMA_CPP_DIR/log_${SCRIPT_NAME}-ppid_$$_$(date +'%Y%m%d_%H%M%S').log"

log() {
  local timestamp
  timestamp=$(date +'%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

log_separator() {
  log "=========================================================================================="
}

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Get the PID of llama-server process (if any)
get_llama_server_pid() {
  pgrep -f "llama-server.*$MODEL_PATH" || true
}

# Check if server is responding on port
check_server_http() {
  local host="$1"
  local port="$2"
  if command_exists curl; then
    curl -s --connect-timeout 5 "http://${host}:${port}/health" &>/dev/null && return 0
  fi
  if command_exists nc; then
    nc -z "$host" "$port" 2>/dev/null && return 0
  fi
  if command_exists bash && [[ -f /dev/tcp/$host/$port ]]; then
    # Bash built-in TCP check
    timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null && return 0
  fi
  return 1
}

# Kill llama-server process forcefully
kill_llama_server() {
  local pid="$1"
  log "ACTION: Attempting to kill llama-server PID: $pid"

  if ! kill -0 "$pid" 2>/dev/null; then
    log "INFO: Process $pid already dead"
    return 0
  fi

  # Try graceful shutdown first
  log "ACTION: Sending SIGTERM to PID $pid"
  kill "$pid" 2>/dev/null || true

  # Wait up to 10 seconds for graceful shutdown
  local count=0
  while [[ $count -lt 10 ]]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      log "INFO: Process $pid terminated gracefully"
      return 0
    fi
    sleep 1
    ((count++))
  done

  # Force kill if still running
  log "ACTION: Process still running, sending SIGKILL to PID $pid"
  kill -9 "$pid" 2>/dev/null || true
  sleep 2

  if kill -0 "$pid" 2>/dev/null; then
    log "WARNING: Process $pid still running despite SIGKILL"
    return 1
  else
    log "INFO: Process $pid terminated via SIGKILL"
    return 0
  fi
}

# Check and clean GPU memory
check_gpu_memory() {
  log "ACTION: Checking GPU memory status"

  local gpu_used_mb=0
  local gpu_total_mb=0
  local llama_gpu_usage_mb=0

  # Try rocm-smi first (most reliable)
  if command_exists rocm-smi; then
    log "INFO: Using rocm-smi to check GPU memory"

    # Parse rocm-smi output - look for VRAM usage
    local smi_output
    smi_output=$(rocm-smi --showmeminfo vram 2>&1)

    # Extract VRAM used and total
    gpu_used_mb=$(echo "$smi_output" | grep -oP 'VRAM Total Used Memory.*: \K[0-9]+' || echo "0")
    gpu_total_mb=$(echo "$smi_output" | grep -oP 'VRAM Total Memory.*: \K[0-9]+' || echo "0")

    # Convert bytes to MB if needed (rocm-smi sometimes reports in bytes)
    if [[ $gpu_used_mb -gt 100000 ]]; then
      gpu_used_mb=$((gpu_used_mb / 1024 / 1024))
    fi
    if [[ $gpu_total_mb -gt 100000 ]]; then
      gpu_total_mb=$((gpu_total_mb / 1024 / 1024))
    fi

    # Check for llama-server processes using GPU
    local gpu_processes
    gpu_processes=$(rocm-smi --showpids 2>&1 | grep -i llama || true)

    if [[ -n "$gpu_processes" ]]; then
      log "INFO: Found llama-server in GPU process list - this may indicate GPU is still allocated"
      # Try to extract VRAM used by llama-server
      llama_gpu_usage_mb=$(echo "$gpu_processes" | grep -oP 'VRAM USED.*?\d+' | grep -oP '\d+' || echo "0")
      if [[ $llama_gpu_usage_mb -gt 1000000000 ]]; then
        llama_gpu_usage_mb=$((llama_gpu_usage_mb / 1024 / 1024))
      fi
    fi
  fi

  # Fallback to amdgpu_top
  if command_exists amdgpu_top && [[ $gpu_used_mb -eq 0 ]]; then
    log "INFO: Using amdgpu_top to check GPU memory"
    local top_output
    top_output=$(amdgpu_top --single-only 2>&1 | grep -i "VRAM" || echo "")

    if [[ -n "$top_output" ]]; then
      gpu_used_mb=$(echo "$top_output" | grep -oP '[\d.]+(?=\s*MB)' | head -1 || echo "0")
      # Remove decimal if present
      gpu_used_mb=${gpu_used_mb%.*}
    fi
  fi

  log "INFO: GPU Memory Status - Used: ${gpu_used_mb}MB / ${gpu_total_mb}MB, llama-server using: ${llama_gpu_usage_mb}MB"

  # If significant VRAM is used (>5GB), GPU might not be fully cleared
  local threshold_mb=5000
  if [[ $gpu_used_mb -gt $threshold_mb ]]; then
    log "WARNING: GPU VRAM usage is ${gpu_used_mb}MB, may need time to clear"
    return 1
  fi

  log "INFO: GPU memory appears free"
  return 0
}

# Wait for GPU memory to be freed
wait_for_gpu_free() {
  local max_wait=30
  local count=0

  log "ACTION: Waiting for GPU memory to be freed (max ${max_wait}s)"

  while [[ $count -lt $max_wait ]]; do
    if check_gpu_memory; then
      return 0
    fi
    sleep 2
    ((count += 2))
  done

  log "WARNING: GPU memory not freed after ${max_wait}s, proceeding anyway"
  return 0
}

# ==============================================================================
# SERVER MANAGEMENT
# ==============================================================================

# Start the llama-server
start_server() {
  log_separator
  log "ACTION: Starting llama-server"

  # Check if binary exists
  if [[ ! -f "$SERVER_BIN" ]]; then
    log "ERROR: Server binary not found: $SERVER_BIN"
    return 1
  fi

  # Check if model exists
  if [[ ! -f "$MODEL_PATH" ]]; then
    log "ERROR: Model file not found: $MODEL_PATH"
    return 1
  fi

  # Check if draft model exists
  if [[ ! -f "$MODEL_DRAFT_PATH" ]]; then
    log "ERROR: Draft model file not found: $MODEL_DRAFT_PATH"
    return 1
  fi

  # Create server log file
  local server_log
  server_log="$LLAMA_CPP_DIR/log_llama-server-qwen35-27b-speculative-ppid_$$_$(date +'%Y%m%d_%H%M%S').log"

  log "INFO: Server log will be: $server_log"
  log "INFO: Main Model: $MODEL_PATH"
  log "INFO: Draft Model: $MODEL_DRAFT_PATH"
  log "INFO: Host: $SERVER_HOST:$SERVER_PORT"

  # Start the server
  log "ACTION: Executing: $SERVER_BIN ${SERVER_ARGS[*]}"

  "$SERVER_BIN" "${SERVER_ARGS[@]}" > "$server_log" 2>&1 &

  local server_pid=$!
  log "INFO: Server started with PID: $server_pid"

  # Wait a bit for the server to initialize
  log "ACTION: Waiting for server to initialize (20 seconds)"
  sleep 20

  # Check if process is still running
  if ! kill -0 "$server_pid" 2>/dev/null; then
    log "ERROR: Server process died during initialization"
    log "INFO: Check server log: $server_log"
    return 1
  fi

  # Check if server is responding
  if check_server_http "$SERVER_HOST" "$SERVER_PORT"; then
    log "SUCCESS: Server is responding on $SERVER_HOST:$SERVER_PORT"
    return 0
  else
    log "WARNING: Server process is running but not yet responding to HTTP"
    log "INFO: This may be normal during model loading - will check on next health cycle"
    return 0
  fi
}

# Check server health
check_server_health() {
  log "ACTION: Checking server health"

  local pid
  pid=$(get_llama_server_pid)

  if [[ -z "$pid" ]]; then
    log "WARNING: No llama-server process found"
    return 1
  fi

  log "INFO: Found llama-server PID: $pid"

  # Check if process is actually running
  if ! kill -0 "$pid" 2>/dev/null; then
    log "WARNING: Process $pid exists in pgrep but is not running (zombie?)"
    return 1
  fi

  # Check HTTP endpoint
  if check_server_http "$SERVER_HOST" "$SERVER_PORT"; then
    log "INFO: Server is healthy and responding"
    return 0
  else
    log "WARNING: Server process running but not responding on $SERVER_HOST:$SERVER_PORT"
    log "ACTION: Server considered unhealthy - will restart"
    return 1
  fi
}

# Restart the server
restart_server() {
  log_separator
  log "ACTION: Server restart initiated"

  local pid
  pid=$(get_llama_server_pid)

  if [[ -n "$pid" ]]; then
    log "ACTION: Killing existing llama-server PID: $pid"
    kill_llama_server "$pid"
  else
    log "INFO: No existing llama-server process found"
  fi

  # Wait for GPU to free up
  wait_for_gpu_free

  # Start fresh server
  if start_server; then
    log "SUCCESS: Server restart completed"
    return 0
  else
    log "ERROR: Server restart failed"
    return 1
  fi
}

# ==============================================================================
# MAIN LOOP
# ==============================================================================

main() {
  log_separator
  log "START: llama-server watchdog wrapper starting"
  log "INFO: Health check interval: ${HEALTH_CHECK_INTERVAL}s"
  log "INFO: Target: $SERVER_HOST:$SERVER_PORT"
  log "INFO: Wrapper log: $LOG_FILE"
  log_separator

  # Initial server start
  if ! start_server; then
    log "ERROR: Failed to start server initially, will retry in loop"
  fi

  # Main monitoring loop
  local iteration=0
  while true; do
    ((iteration++))
    log "ACTION: Health check iteration #$iteration"

    if check_server_health; then
      log "INFO: Server healthy, sleeping for ${HEALTH_CHECK_INTERVAL}s"
    else
      log "WARNING: Server unhealthy, attempting restart"
      restart_server
    fi

    log "INFO: Sleeping until next check (${HEALTH_CHECK_INTERVAL}s)"
    sleep "$HEALTH_CHECK_INTERVAL"
  done
}

# ==============================================================================
# SCRIPT ENTRY POINT
# ==============================================================================

# Trap signals for graceful shutdown
cleanup() {
  log ""
  log_separator
  log "STOP: Watchdog wrapper received termination signal"
  log "INFO: Note: The llama-server will continue running in background"
  log "INFO: To stop it manually: pkill -f 'llama-server.*$MODEL_PATH'"
  log_separator
  exit 0
}

trap cleanup SIGINT SIGTERM

# Run main loop
main
