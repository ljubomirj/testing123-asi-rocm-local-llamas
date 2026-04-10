#!/bin/bash
# Start llama-server with Qwen3.5-122B-A10B on macbook2 (Metal)
# Label: llama_cpp-metal-qwen3.5-122b-a10b

SERVER=~/llama.cpp/build.macbook2-metal/bin/llama-server
MODEL=~/llama.cpp/models/Qwen3.5-122B-A10B-UD-Q3_K_XL-00001-of-00003.gguf

exec "$SERVER" \
    --model "$MODEL" \
    --host 127.0.0.1 \
    --port 8081 \
    --parallel 1 \
    --ctx-size 262144 \
    --flash-attn on \
    --cache-type-k q8_0 \
    --cache-type-v q8_0 \
    --jinja \
    --cache-ram 8192 \
    --cache-reuse 512 \
    --cache-prompt \
    --batch-size 1024 \
    --ubatch-size 256 \
    --threads-batch 6 \
    --threads 6 \
    --mlock \
    --kv-unified \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 20 \
    --min-p 0
