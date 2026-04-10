#!/bin/bash
# llama-server for GLM-4.7-Flash Q4_K_XL (17GB, 200K context)
# Using baseline parameters (2048/512/32GB) - optimized params showed no benefit

cd ~/llama.cpp

TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="log_llama-server-q4-${TIMESTAMP}.log"

echo "Starting Q4 llama-server with:"
echo "  - Model: Q4_K_XL (17GB, 200K context)"
echo "  - Baseline parameters (2048/512/32GB)"
echo "  - Prometheus metrics enabled"
echo "  - Performance timings enabled"
echo ""
echo "Model specs:"
echo "  - Size: 17GB (vs Q5's 21GB)"
echo "  - Context: 200K tokens (vs Q5's 95K)"
echo "  - Quality: 4-bit (vs Q5's 5-bit)"
echo ""
echo "Endpoints:"
echo "  - Chat: http://192.168.1.251:8081/v1/chat/completions"
echo "  - Metrics: http://192.168.1.251:8081/metrics"
echo "  - Slots: http://192.168.1.251:8081/slots"
echo "  - Health: http://192.168.1.251:8081/health"
echo ""
echo "Log: ${LOG_FILE}"
echo ""

./build/bin/llama-server \
  --device Vulkan0 \
  --gpu-layers all \
  --ctx-size 200000 \
  --host 192.168.1.251 \
  --port 8081 \
  --model ~/llama.cpp/models/GLM-4.7-Flash-UD-Q4_K_XL.gguf \
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
  --batch-size 2048 \
  --ubatch-size 512 \
  --threads-batch 10 \
  --threads 10 \
  --mlock \
  --no-mmap \
  --kv-unified \
  --metrics \
  --perf \
  > "${LOG_FILE}" 2>&1 &

SERVER_PID=$!
echo "Server started with PID: ${SERVER_PID}"
echo "Waiting for server to be ready..."

# Wait for server to respond
for i in {1..60}; do
  if curl -s http://192.168.1.251:8081/health > /dev/null 2>&1; then
    echo "✓ Server ready!"
    echo ""
    echo "Monitor with:"
    echo "  tail -f ${LOG_FILE}"
    echo "  curl http://192.168.1.251:8081/slots | jq"
    echo "  curl http://192.168.1.251:8081/metrics"
    exit 0
  fi
  sleep 1
done

echo "Server didn't respond within 60 seconds. Check ${LOG_FILE}"
exit 1
