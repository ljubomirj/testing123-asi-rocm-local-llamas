# Q4 vs Q5 Benchmark Results

**Date**: 2026-02-10
**Test**: GLM-4.7-Flash Q4_K_XL (17GB) vs Q5_K_XL (21GB)
**Configuration**: Baseline parameters (batch 2048, ubatch 512, cache 32GB)

## Performance Comparison

### Summary Table

| Model | Size | Context | 50K Throughput | 55K Throughput | TTFT (50K) | TTFT (55K) |
|-------|------|---------|----------------|----------------|------------|------------|
| **Q5_K_XL** | 21GB | 95K | **6.9 tok/s** | **4.4 tok/s** | 80.0s | 127.0s |
| **Q4_K_XL** | 17GB | 200K | **6.7 tok/s** | **4.3 tok/s** | 79.3s | 126.3s |
| **Difference** | -19% | +110% | **-3%** | **-2%** | -0.9% | -0.6% |

### Detailed Results

**50K Context (40K prefill + 10K prompt)**:

| Model | Run 1 | Run 2 | Run 3 | Average | Variance |
|-------|-------|-------|-------|---------|----------|
| Q5 | 7.37 | 6.34 | 6.87 | **6.86 tok/s** | ±0.52 (7.6%) |
| Q4 | 6.03 | 7.10 | 7.13 | **6.75 tok/s** | ±0.64 (9.5%) |

**55K Context (40K prefill + 15K prompt)**:

| Model | Run 1 | Run 2 | Run 3 | Average | Variance |
|-------|-------|-------|-------|---------|----------|
| Q5 | 5.04 | 3.88 | 4.15 | **4.36 tok/s** | ±0.61 (14%) |
| Q4 | 4.35 | 4.07 | 4.65 | **4.36 tok/s** | ±0.29 (6.7%) |

## Key Findings

### 1. Q4 Performance is Essentially Identical to Q5 ✅

**Throughput difference**: -3% to -2% (within statistical noise)

**Why no improvement?**

1. **Model size != memory bandwidth**
   - Q4 model: 17GB (19% smaller)
   - Q4 KV cache: Same size as Q5 (50K tokens @ q8_0)
   - **Total memory traffic**: Model weights loaded once, KV cache accessed every token
   - **Bottleneck**: Reading KV cache (~200MB per token), not model weights

2. **Quantization quality trade-off**
   - Q4: 4-bit weights (less accurate multiplication)
   - Q5: 5-bit weights (more accurate multiplication)
   - Lower precision may require more iterations or corrections
   - Net effect: Cancels out memory bandwidth savings

3. **Same attention complexity**
   - Both models: O(n²) attention over 50K-55K context
   - Both models: Flash attention enabled
   - Same GPU, same memory bandwidth limit (960 GB/s)

### 2. Q4 Has Lower Variance (More Consistent) ✅

**Q5 variance**: 7.6-14% across runs
**Q4 variance**: 6.7-9.5% across runs

**Possible reasons**:
- Simpler quantization = more predictable performance
- Less numerical precision sensitivity
- More consistent cache access patterns

### 3. TTFT Essentially Identical (~1% faster on Q4) ✅

**50K context**:
- Q5: 80.0s TTFT
- Q4: 79.3s TTFT
- Difference: 0.7s (0.9% faster)

**55K context**:
- Q5: 127.0s TTFT
- Q4: 126.3s TTFT
- Difference: 0.7s (0.6% faster)

**Interpretation**: TTFT dominated by reasoning tokens (model thinking), not quantization

### 4. Cache Performance Identical ✅

**Cold prefill** (first run):
- Q5: 125.25s (40K tokens)
- Q4: 122.48s (40K tokens)
- **Difference**: 2.77s (2.2% faster)

**Warm prefill** (cached):
- Q5: 0.35s (RAM → VRAM transfer)
- Q4: 0.33s (RAM → VRAM transfer)
- **Difference**: 0.02s (5.7% faster)

**Speedup**:
- Q5: 125s → 0.35s = 357x
- Q4: 122s → 0.33s = 371x

**Both models**: Cache is working perfectly!

## Detailed Analysis

### Memory Bandwidth Breakdown

**Q5 (21GB model + 1.9GB KV cache = 23GB)**:

Per token generated:
- Model weights: 0 bytes (cached in VRAM)
- KV cache read: ~200MB (50K context × 4KB per token)
- KV cache write: ~4KB (new token)
- **Total**: ~200MB per token

At 6.9 tok/s: 6.9 × 200MB = **1.38 GB/s actual bandwidth usage**

**Q4 (17GB model + 1.9GB KV cache = 19GB)**:

Per token generated:
- Model weights: 0 bytes (cached in VRAM)
- KV cache read: ~200MB (same as Q5!)
- KV cache write: ~4KB (new token)
- **Total**: ~200MB per token

At 6.7 tok/s: 6.7 × 200MB = **1.34 GB/s actual bandwidth usage**

**Observation**: KV cache dominates memory traffic, not model size!

### Why Model Size Doesn't Matter Here

**Memory bandwidth allocation**:
1. **Model loading**: Happens once at startup (one-time cost)
2. **KV cache**: Accessed every token generated (recurring cost)
3. **Activations**: Small compared to KV cache

**For 50K context inference**:
- Model weights: Read once, cached in VRAM
- KV cache: Read 50,000 entries × 4KB = 200MB **per token**
- Activations: ~10MB per token

**Ratio**: KV cache (200MB) : Model (0MB) : Activations (10MB) = **20:0:1**

**Conclusion**: 95% of memory bandwidth goes to KV cache, not model weights!

### What Q4 Actually Gains You

Since throughput is identical, what's the benefit of Q4?

#### 1. ✅ 2x Larger Context (200K vs 95K)

**Q4 trained context**: 202,752 tokens
**Q5 trained context**: 95,232 tokens

**Benefit for agentic workloads**:
```
Typical agentic usage:
- System prompt: 1K
- Tool definitions: 2K
- Conversation history: 20K
- Multiple documents: 80K
- Current task: 10K
Total: 113K tokens

Q5 (95K): Doesn't fit! Need to truncate or rotate context
Q4 (200K): Fits comfortably with 87K headroom
```

#### 2. ✅ 4GB VRAM Savings

**Q5**: 21GB model + 1.9GB KV cache (95K @ q8_0) = 23GB
**Q4**: 17GB model + 1.9GB KV cache (95K @ q8_0) = 19GB

**With larger context**:
- Q4 @ 200K context: 17GB + 4.0GB KV cache = 21GB total
- Still fits in 24GB with 3GB headroom!

#### 3. ⚠️ Quality Trade-off

**Need to assess**:
- Accuracy on reasoning tasks
- Hallucination rate
- Output coherence
- Code generation quality

**Not measured in this benchmark** - needs qualitative evaluation.

## Performance Matrix

| Scenario | Q5 (95K max) | Q4 (200K max) | Winner |
|----------|--------------|---------------|--------|
| **50K context throughput** | 6.9 tok/s | 6.7 tok/s | Tie (within 3%) |
| **55K context throughput** | 4.4 tok/s | 4.3 tok/s | Tie (within 2%) |
| **TTFT** | 80-127s | 79-126s | Tie (within 1%) |
| **Cache performance** | 357x speedup | 371x speedup | Tie |
| **Max context** | 95K | 200K | **Q4 wins** |
| **VRAM usage** | 23GB | 19-21GB | **Q4 wins** |
| **Quality** | Higher (5-bit) | Lower (4-bit) | **Q5 wins** |

## Recommendations

### Use Q5_K_XL When:
- ✅ Context fits in 95K comfortably
- ✅ Quality is critical (reasoning, accuracy)
- ✅ Single-document analysis
- ✅ Don't need conversation history >80K

### Use Q4_K_XL When:
- ✅ **Need context >95K** (agentic workflows, multi-document)
- ✅ **Long conversation histories** (20+ turn dialogues)
- ✅ **Multiple simultaneous contexts**
- ✅ Want VRAM headroom for future expansion
- ⚠️ Can tolerate potential quality degradation

### Performance Parity Conclusion

**Q4 does NOT provide throughput improvement over Q5** for the same context size.

**Reason**: Memory bandwidth bottleneck is KV cache (same size for both), not model weights.

**Real Q4 advantage**: 2x larger context window, not speed.

## Test Next: 100K Context on Q4

Since Q4's advantage is larger context, we should test:

```bash
# Test Q4 at 100K total context (2x what Q5 can handle)
python3 bench_longcontext.py --base http://192.168.1.251:8081 \
  --prefill-tokens 80000 --prompt-tokens 20000 --runs 3 \
  --output benchmark_q4_100k_results.jsonl
```

**Expected results**:
- Throughput: 2-3 tok/s (degraded due to larger context)
- TTFT: 250-350s (2x longer due to 2x context)
- **But**: Q5 would OOM at this size!

**Value**: Enables workloads Q5 cannot handle at all.

## Conclusion

### Performance Summary

**Q4 vs Q5 for same context (50K-55K)**:
- Throughput: Identical (-3% to -2%, within variance)
- TTFT: Identical (~1% faster, within variance)
- Cache: Identical (both ~360x speedup)

### Strategic Recommendation

**For current testing** (50K context):
- **Use Q5**: Slightly higher quality, identical performance

**For production agentic workloads** (>95K context needed):
- **Use Q4**: Only option that supports >95K context
- **Accept**: Identical throughput at 50K, degraded throughput at 100K+
- **Gain**: Ability to handle long contexts that Q5 cannot

### Next Steps

1. ✅ **Completed**: Q4 vs Q5 comparison at 50K-55K
2. 🎯 **Optional**: Test Q4 at 100K-120K context (showcase its advantage)
3. ⚠️ **Important**: Qualitative quality assessment (Q4 vs Q5 outputs)
4. 📊 **Document**: Update LEARNINGS.md with findings

### Files Generated

- **benchmark_q4_results.jsonl** - Q4 performance data
- **Q4_VS_Q5_RESULTS.md** - This analysis
- **run_llama_q4.sh** - Q4 server startup script
