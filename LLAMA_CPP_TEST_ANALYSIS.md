# llama.cpp Test Analysis - IMPORTANT CONTEXT

## Test Conditions (What We Actually Measured)

### Server Command Used
```bash
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
  --cache-ram 32768 \
  --cache-reuse 512 \
  --cache-prompt \
  --batch-size 2048 \
  --ubatch-size 512 \
  --threads-batch 10 \
  --threads 10 \
  --mlock \
  --no-mmap \
  --kv-unified
```

### Test Parameters
- **Prompt lengths**: 100, 1000, 5000 characters (~25, 250, 1250 tokens)
- **Max generation**: 512 tokens per request
- **Runs per length**: 3 (to measure cache effectiveness)
- **Context window**: 95,000 tokens (configured but NOT filled)
- **KV cache**: q8_0 quantized, 32GB RAM cache

## Critical Issue: Context Was NOT Filled

**YOU ARE CORRECT** - This is a critical oversight!

### What Was Actually Tested:
- **Empty context** at start
- Small prompts (100-5000 chars = 25-1250 tokens)
- Only measuring the **first 5K tokens** of the 95K context window
- Cache effectiveness only for prompt repetition, not realistic long-context usage

### Why This Matters:
1. **Memory bandwidth**: Processing with empty cache vs. 40K-50K tokens in KV cache is VERY different
2. **Attention computation**: O(n²) complexity - attention over 1K tokens vs 50K tokens is ~2500x more compute
3. **Cache pressure**: GPU memory bandwidth becomes bottleneck with large KV cache
4. **Realistic use**: Your use case likely involves maintaining long context (conversations, documents)

## Realistic Test Scenario (Recommended)

### Phase 1: Fill Context
```python
# Prefill with 40K-50K tokens of context
context = generate_or_load_long_context(40000)  # ~40K tokens
# Send to server to fill KV cache
response = requests.post('http://192.168.1.251:8081/v1/completions',
    json={'prompt': context, 'max_tokens': 1})
```

### Phase 2: Test With Filled Context
- **Test prompt**: 10K-15K tokens (40-60KB text)
- **Context in cache**: 40K tokens
- **Total active context**: ~50K-55K tokens
- **This tests**:
  - Attention over large KV cache
  - Memory bandwidth with realistic usage
  - Cache effectiveness under pressure

## Expected Performance Degradation

Based on typical LLM behavior with long context:

| Context Fill | Expected Speed | Reason |
|--------------|---------------|--------|
| Empty (0-5K) | 94-112 tok/s | What we measured |
| 20K tokens | ~60-80 tok/s | Moderate attention cost |
| 40K tokens | ~40-60 tok/s | High attention cost |
| 60K+ tokens | ~20-40 tok/s | Memory bandwidth limited |

**NOTE**: These are rough estimates. Actual performance depends on:
- GPU memory bandwidth (7900 XTX: 960 GB/s)
- KV cache quantization (q8_0 helps)
- Flash attention effectiveness
- Batch size and other parameters

## Performance Analysis of Current Results

### What We Learned:
1. **Warm cache is FAST**: 0.03s TTFT (first token) when cached
2. **Cold prompt**: 0.19-0.64s TTFT for 5K char prompt (expected)
3. **Generation speed**: 400-450 chars/sec = ~100-112 tok/s (very good for empty context)
4. **Cache works**: Huge difference between run 1 (cold) and runs 2-3 (warm)

### What We DIDN'T Learn:
1. Performance with realistic context length (40K-60K tokens)
2. Memory bandwidth limits under full load
3. Concurrent request handling with large contexts
4. Cache effectiveness when context is large

## ACTUAL LONG-CONTEXT RESULTS (2026-02-10)

**Test completed with realistic context!**

```bash
python3 bench_longcontext.py \
  --base http://192.168.1.251:8081 \
  --prefill-tokens 40000 \
  --prompt-tokens 10000,15000 \
  --runs 3
```

### Results Summary:

| Context Size | Prompt Size | Total Tokens | TTFT (avg) | Throughput | Degradation |
|--------------|-------------|--------------|------------|------------|-------------|
| Empty (0-5K) | 100-5K chars | ~1K-5K | 0.03-0.64s | **94-112 tok/s** | Baseline |
| 40K tokens | 10K tokens | ~50K | **79.998s** | **6.9 tok/s** | **93% slower** |
| 40K tokens | 15K tokens | ~55K | **127.016s** | **4.4 tok/s** | **96% slower** |

### Critical Findings:

1. **TTFT Exploded**: 0.03s → 80-127s (2600-4200x slower!)
   - GLM-4.7-Flash does extensive reasoning before output
   - Processing 50K-55K context takes significant time

2. **Throughput Collapsed**: 94-112 tok/s → 4-7 tok/s (94-96% slower)
   - O(n²) attention complexity hits hard with large context
   - Memory bandwidth becomes primary bottleneck
   - Matches expected 40-60 tok/s degradation pattern (actually worse)

3. **Caching Still Works**:
   - First prefill: 125s (cold)
   - Subsequent prefills: 0.35s (warm, 357x faster)

4. **Context Size Impact**:
   - 50K total: 6.9 tok/s
   - 55K total: 4.4 tok/s
   - **37% degradation** with just 5K more tokens!

### Why The Huge TTFT?

The 80-127 second TTFT is likely due to:
- GLM-4.7-Flash's reasoning tokens (visible in stream as `reasoning_content`)
- Model thinks extensively before responding
- Large context processing overhead
- Flash attention with q8_0 KV cache quantization

This gives you:
- **Realistic performance** numbers for production use
- **True bottlenecks** identified (TTFT and throughput both crushed)
- **Comparative baseline** for when SGLang/vLLM become available

## Why 94-112 tok/s Seemed "Too Fast"

It WAS fast because:
1. Context was essentially empty (only 1-5K tokens)
2. Attention complexity was minimal
3. No memory bandwidth bottleneck yet
4. GPU had plenty of room to work

With 40K-50K tokens in context, expect **40-60 tok/s** (still respectable, but more realistic).

## Action Items

1. **Create realistic benchmark** with context prefilling
2. **Test with 40K context + 10K-15K prompts**
3. **Document true performance** for long-context scenarios
4. **Use these numbers** as the real baseline for comparison

Would you like me to create an updated benchmark script that handles context prefilling?
