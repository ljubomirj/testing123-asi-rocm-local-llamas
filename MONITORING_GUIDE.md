# llama-server Monitoring & Instrumentation Guide

## Available Instrumentation

### 1. Prometheus Metrics Endpoint (`--metrics`)

**URL**: `http://192.168.1.251:8081/metrics`

**Key metrics** for tuning:

```bash
# Check all available metrics
curl -s http://192.168.1.251:8081/metrics

# Key metrics to watch:
curl -s http://192.168.1.251:8081/metrics | grep -E "prompt_tokens|kv_cache|batch|decode"
```

**Important metrics**:
- `llamacpp:prompt_tokens_total` - Total tokens processed in prompts
- `llamacpp:tokens_predicted_total` - Total tokens generated
- `llamacpp:prompt_tokens_seconds` - Prompt processing speed (tokens/sec)
- `llamacpp:predicted_tokens_seconds` - Generation speed (tokens/sec)
- `llamacpp:kv_cache_usage_ratio` - KV cache utilization (0.0-1.0)
- `llamacpp:kv_cache_tokens` - Current tokens in KV cache
- `llamacpp:requests_processing` - Active requests
- `llamacpp:requests_deferred` - Queued requests (should be 0 for single-user)

### 2. Slots Endpoint (`--slots`, default enabled)

**URL**: `http://192.168.1.251:8081/slots`

**Real-time slot monitoring**:

```bash
# Pretty-print current slot states
curl -s http://192.168.1.251:8081/slots | jq

# Watch slot activity in real-time
watch -n 1 'curl -s http://192.168.1.251:8081/slots | jq -r ".[] | select(.state != null) | {id, state, n_prompt_tokens_processed, n_decoded, cache_used: .cache_tokens}"'
```

**Key fields**:
```json
{
  "id": 0,                           // Slot ID
  "state": 0,                         // 0=idle, 1=processing, 2=waiting
  "n_ctx": 95232,                     // Context size
  "n_prompt_tokens_processed": 42567, // Tokens processed in prompt
  "n_decoded": 731,                   // Tokens generated
  "cache_tokens": 40123,              // Tokens loaded from cache
  "truncated": false,                 // Whether prompt was truncated
  "t_prompt_processing": 80.5,        // Time spent processing prompt (seconds)
  "t_token_generation": 99.2,         // Time spent generating (seconds)
  "tokens_predicted": 731,            // Same as n_decoded
  "tokens_evaluated": 42567,          // Total tokens evaluated
  "n_past": 43298,                    // Total context used (prompt + generated)
  "stopping_word": ""                 // Stop reason
}
```

**Most useful for tuning**:
- `cache_tokens` / `n_prompt_tokens_processed` = **cache hit rate**
- `t_prompt_processing` = **TTFT** (what we're seeing at 80-127s)
- `n_decoded` / `t_token_generation` = **throughput** (tok/s)

### 3. Performance Timings (`--perf`)

**Enabled by default**, shows in server logs:

```bash
# View performance timings in real-time
tail -f log_llama-server-optimized-*.log | grep "perf:"
```

**Example output**:
```
perf: prompt eval time    = 80567.23 ms /  42567 tokens ( 1.89 ms per token, 528.37 tokens per second)
perf: eval time           = 99234.56 ms /   730 runs   (135.94 ms per token,  7.36 tokens per second)
perf: total time          = 179801.79 ms / 43297 tokens
```

**Key metrics**:
- **Prompt eval**: Time to process input (includes cache loading)
- **Eval time**: Time to generate output
- **ms per token**: Latency per token (prompt and generation)
- **tokens per second**: Throughput (what we're optimizing)

### 4. Server Logs

**Startup info** (useful for debugging):

```bash
tail -f log_llama-server-optimized-*.log | grep -E "INF|WRN|ERR"
```

**Key log messages**:
```
INF initializing slots, n_slots = 4
INF prompt cache is enabled, size limit: 65536 MiB
INF KV cache size: 1843.00 MiB (q8_0)
INF flash attention enabled
```

**Warning signs**:
```
WRN cache_reuse is not supported by this context  # KV shifting disabled
ERR slot unavailable                              # All slots busy (shouldn't happen)
WRN ran out of KV cache for slot                  # Need smaller context or fewer slots
```

---

## Monitoring During Benchmark

### Real-time Dashboard (Terminal 1)

```bash
# Watch slot activity + cache hit rate
watch -n 1 '
echo "=== Slot Status ==="
curl -s http://192.168.1.251:8081/slots | jq -r ".[] | select(.state != null) | {
  slot: .id,
  state: (if .state == 0 then \"idle\" elif .state == 1 then \"processing\" else \"waiting\" end),
  prompt_tokens: .n_prompt_tokens_processed,
  generated: .n_decoded,
  cache_hit_rate: (if .n_prompt_tokens_processed > 0 then (.cache_tokens * 100 / .n_prompt_tokens_processed | floor) else 0 end),
  ttft: .t_prompt_processing,
  throughput: (if .t_token_generation > 0 then (.n_decoded / .t_token_generation | floor) else 0 end)
}"

echo ""
echo "=== Metrics ==="
curl -s http://192.168.1.251:8081/metrics | grep -E "kv_cache_usage|tokens_seconds|requests_processing"
'
```

### Run Benchmark (Terminal 2)

```bash
cd ~/sglang-rocm-glm-4.7-flash
python3 bench_longcontext.py --base http://192.168.1.251:8081 \
  --prefill-tokens 40000 --prompt-tokens 10000,15000 --runs 3
```

### Check Logs (Terminal 3)

```bash
tail -f ~/llama.cpp/log_llama-server-optimized-*.log | grep -E "perf:|cache|slot"
```

---

## Interpreting Results for Parameter Tuning

### 1. Cache Hit Rate

**Good**: `cache_tokens` / `n_prompt_tokens_processed` > 95%
**Check**: Are subsequent runs hitting cache?

**If low (<90%)**:
- Increase `--cache-ram` (more RAM storage)
- Check `--cache-reuse` threshold (lower = more aggressive)
- Verify `--cache-prompt` is enabled

**Current expectation**: Should see ~99% hit rate on runs 2-3 (0.35s vs 125s)

### 2. KV Cache Usage

**Metric**: `llamacpp:kv_cache_usage_ratio`

**Good**: 0.5 - 0.8 (50-80% utilization)
**Concerning**: >0.95 (close to capacity)

**If >0.95**:
- Risk of KV cache eviction
- Consider: Smaller context, fewer slots, or more aggressive quantization (q8_0→q4_0)

**Current**: ~50K/95K = ~52% (healthy)

### 3. Batch Efficiency

**Watch in logs**: Batch fill rate

**If you see**:
```
batch: n_tokens = 512, avg = 256.3  # <-- Low average
```

**Meaning**: Batches aren't filling up (inefficient GPU usage)

**Solutions**:
- Reduce `--batch-size` (less overhead waiting for batch to fill)
- Increase request rate (more concurrent requests)

**For single-user**: Batch size doesn't matter much, ubatch-size is more important

### 4. Throughput vs Batch Size

**Test methodology**:
1. Run benchmark with batch-size 2048, ubatch-size 512 (baseline)
2. Run benchmark with batch-size 4096, ubatch-size 1024 (optimized)
3. Compare `tokens_per_sec` from results

**Expected**:
- Baseline: 6.9 tok/s (50K), 4.4 tok/s (55K)
- Optimized: 8-9 tok/s (50K), 5-6 tok/s (55K)
- **Improvement**: 15-30%

**If no improvement or slower**:
- OOM occurred (check logs for errors)
- GPU stalled (larger batches = more memory bandwidth)
- Reduce back to 2048/512

### 5. TTFT (Time To First Token)

**Measured**: `t_prompt_processing` from slots endpoint

**Current**: 80-127 seconds for 50K-55K context

**This is dominated by**:
- Model reasoning tokens (GLM-4.7-Flash specific)
- O(n²) attention over long context
- Cache miss on first run

**NOT affected by**:
- Batch size (single request, no batching)
- Thread count (GPU-bound, not CPU-bound)
- RAM cache size (only helps on cache hit)

**To improve TTFT**: Only possible with different model or model optimization (speculative decoding, etc.)

---

## Quick Parameter Tuning Workflow

### Step 1: Establish Baseline

```bash
# Start server with current params
./run_llama_optimized.sh

# Run benchmark
python3 bench_longcontext.py --base http://192.168.1.251:8081 \
  --prefill-tokens 40000 --prompt-tokens 10000,15000 --runs 3

# Record results
# - TTFT: [X]s
# - Throughput: [Y] tok/s
# - Cache hit rate: [Z]%
```

### Step 2: Monitor During Run

```bash
# Terminal 1: Watch slots
watch -n 1 'curl -s http://192.168.1.251:8081/slots | jq'

# Terminal 2: Watch metrics
watch -n 5 'curl -s http://192.168.1.251:8081/metrics | grep tokens_seconds'

# Terminal 3: Watch logs
tail -f log_llama-server-optimized-*.log | grep perf
```

### Step 3: Analyze Results

```bash
# Check final metrics
curl -s http://192.168.1.251:8081/metrics | \
  grep -E "prompt_tokens|predicted_tokens|kv_cache" | \
  sort

# Compare with baseline
diff benchmark_longcontext_results.jsonl benchmark_longcontext_results_optimized.jsonl
```

### Step 4: Iterate

If throughput improved: Keep changes
If throughput same/worse: Revert changes
If OOM: Reduce batch sizes

---

## Monitoring Commands Cheatsheet

```bash
# Health check
curl -s http://192.168.1.251:8081/health

# Current slots state (pretty)
curl -s http://192.168.1.251:8081/slots | jq

# Cache hit rate calculation
curl -s http://192.168.1.251:8081/slots | jq -r '
  .[] | select(.state != null) |
  "Cache hit: \(.cache_tokens)/\(.n_prompt_tokens_processed) = \((.cache_tokens * 100 / .n_prompt_tokens_processed | floor))%"
'

# Prometheus metrics (key ones)
curl -s http://192.168.1.251:8081/metrics | \
  grep -E "kv_cache|tokens_seconds|requests"

# Live performance monitoring
tail -f log_llama-server-*.log | grep -E "perf:|cache|TTFT"

# GPU memory usage (separate from llama-server)
watch -n 5 'rocm-smi --showmeminfo vram'
```

---

## Expected Metrics with Optimized Config

### Startup (from logs)

```
INF prompt cache is enabled, size limit: 65536 MiB  ✓ 64GB
INF KV cache size: 1843.00 MiB (q8_0)               ✓ Same
INF n_batch = 4096                                  ✓ Doubled
INF n_ubatch = 1024                                 ✓ Doubled
```

### During First Run (Cold)

```json
{
  "n_prompt_tokens_processed": 42567,
  "cache_tokens": 0,                    // First run, no cache
  "t_prompt_processing": 125.5,         // Slow (cold)
  "n_decoded": 731,
  "t_token_generation": 99.2,
  "throughput": 7.4                     // Target: 8-9 tok/s
}
```

### During Subsequent Runs (Warm)

```json
{
  "n_prompt_tokens_processed": 42567,
  "cache_tokens": 42567,                // 100% cache hit!
  "t_prompt_processing": 0.35,          // Fast (warm)
  "n_decoded": 730,
  "t_token_generation": 99.5,
  "throughput": 7.3                     // Should improve to 8-9 tok/s
}
```

### Prometheus Metrics

```
llamacpp:kv_cache_usage_ratio 0.52            # 50K / 95K
llamacpp:prompt_tokens_seconds 528.37         # Initial prompt processing
llamacpp:predicted_tokens_seconds 7.36        # Target: improve to 8-9
```

---

## Next Steps

1. **Stop current server**: `pkill llama-server`
2. **Start optimized**: `./run_llama_optimized.sh`
3. **Monitor in real-time**: Use watch commands above
4. **Run benchmark**: Same command as before
5. **Compare results**: Old vs new JSONL files
6. **Analyze**: Check if throughput improved 15-30%

If successful, document in LEARNINGS.md.
If OOM, reduce batch sizes and retry.
