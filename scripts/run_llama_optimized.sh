#!/bin/bash
# Optimized llama-server for GLM-4.7-Flash Q5 with instrumentation
# Improvements: 2x cache-ram, 2x batch sizes, metrics enabled

cd ~/llama.cpp

TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="log_llama-server-optimized-${TIMESTAMP}.log"

echo "Starting optimized llama-server with:"
echo "  - 64GB RAM cache (doubled)"
echo "  - 4096 batch size (doubled)"
echo "  - 1024 ubatch size (doubled)"
echo "  - Prometheus metrics enabled"
echo "  - Performance timings enabled"
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
  --ctx-size 95000 \
  --host 192.168.1.251 \
  --port 8081 \
  --model ~/llama.cpp/models/GLM-4.7-Flash-UD-Q5_K_XL.gguf \
  --temp 1.0 \
  --top-p 0.95 \
  --min-p 0.01 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --jinja \
  --cache-ram 65536 \
  --cache-reuse 512 \
  --cache-prompt \
  --batch-size 4096 \
  --ubatch-size 1024 \
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
for i in {1..30}; do
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

echo "Server didn't respond within 30 seconds. Check ${LOG_FILE}"
exit 1
