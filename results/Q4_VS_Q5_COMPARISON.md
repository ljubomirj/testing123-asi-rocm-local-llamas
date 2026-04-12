# Q4 vs Q5 Model Comparison for GLM-4.7-Flash

## Available Models

| Model | Size | Context | VRAM Savings | Quality |
|-------|------|---------|--------------|---------|
| **Q5_K_XL** | 21GB | 95K tokens | Baseline | Higher |
| **Q4_K_XL** | 17GB | 200K tokens | 4GB (19%) | Lower |

## Key Trade-offs

### Q5_K_XL (Current)
**Pros**:
- ✅ Better quality (5-bit vs 4-bit quantization)
- ✅ Proven performance (4-7 tok/s for 50K context)
- ✅ Less quality degradation

**Cons**:
- ❌ Larger VRAM footprint (21GB)
- ❌ Limited to 95K context
- ❌ May be tight for agentic workloads with multiple context windows

**Current VRAM usage** (estimated):
- Model weights: ~21GB (Q5)
- KV cache (95K, q8_0): ~1.9GB
- **Total**: ~23GB / 24GB (tight!)

### Q4_K_XL (To Test)
**Pros**:
- ✅ 4GB VRAM savings (21GB → 17GB)
- ✅ **2x larger context** (200K vs 95K)
- ✅ More headroom for KV cache
- ✅ Better for agentic workloads (longer conversations, larger document analysis)

**Cons**:
- ❌ Lower quality (4-bit quantization)
- ❌ May show more degradation in reasoning tasks
- ❌ Unknown performance characteristics

**Expected VRAM usage** (200K context):
- Model weights: ~17GB (Q4)
- KV cache (200K, q8_0): ~4.0GB (2x larger context)
- **Total**: ~21GB / 24GB (more comfortable)

## Context Size Impact for Agentic Workloads

### Why 95K Might Be Tight

**Typical agentic workflow**:
1. System prompt: ~1K tokens
2. Tool definitions: ~2K tokens
3. Conversation history: ~10-20K tokens
4. Document/context: ~40-60K tokens
5. Current task: ~5-10K tokens
6. **Total needed**: ~60-90K tokens

**With 95K context**:
- ✅ Fits, but barely
- ❌ Little room for growth
- ❌ Risk of context eviction/truncation

**With 200K context**:
- ✅ Plenty of headroom (60-90K / 200K = 30-45% usage)
- ✅ Can handle longer conversations
- ✅ Can cache more tool outputs
- ✅ Better for multi-turn reasoning

## Performance Expectations

### Q5 Baseline (Measured)
| Context | TTFT | Throughput |
|---------|------|------------|
| 50K | 80s | 6.9 tok/s |
| 55K | 127s | 4.4 tok/s |

### Q4 Predictions (To Measure)

**Hypothesis 1: Same context (50K-55K)**
- Model is 19% smaller → less memory bandwidth needed
- Expected throughput: **7.5-8.5 tok/s** (10-20% improvement)
- TTFT: Similar (dominated by attention, not quantization)

**Hypothesis 2: Larger context (100K-120K)**
- More KV cache → more memory bandwidth needed
- O(n²) attention kicks in harder
- Expected throughput: **3-4 tok/s** (degradation from context size)
- TTFT: **200-300s** (much slower with larger context)

**Hypothesis 3: Quality degradation**
- 4-bit vs 5-bit quantization
- May see more hallucinations, lower accuracy
- Need qualitative assessment of outputs

## Recommended Test Plan

### Phase 1: Same Context (50K-55K)
**Goal**: Compare Q4 vs Q5 apples-to-apples

```bash
# Start Q4 server
./run_llama_q4.sh

# Run same benchmark
python3 bench_longcontext.py --base http://192.168.1.251:8081 \
  --prefill-tokens 40000 --prompt-tokens 10000,15000 --runs 3 \
  --output benchmark_q4_50k_results.jsonl

# Compare
diff benchmark_longcontext_results.jsonl benchmark_q4_50k_results.jsonl
```

**Success metrics**:
- Throughput: >7.5 tok/s (10%+ improvement over Q5's 6.9)
- Quality: Outputs still coherent and accurate
- VRAM: Check `rocm-smi` for headroom

### Phase 2: Larger Context (100K-120K)
**Goal**: Test Q4's 200K context advantage

```bash
# Test with 80K prefill + 20K prompts
python3 bench_longcontext.py --base http://192.168.1.251:8081 \
  --prefill-tokens 80000 --prompt-tokens 20000,25000 --runs 3 \
  --output benchmark_q4_100k_results.jsonl
```

**Success metrics**:
- VRAM: Doesn't OOM (should have 3GB headroom)
- Throughput: Even if 3-4 tok/s, it's better than Q5's OOM
- Use case: Enables agentic workloads Q5 can't handle

### Phase 3: Quality Assessment
**Goal**: Verify Q4 quality is acceptable

**Manual tests**:
1. Complex reasoning task (math, logic)
2. Document summarization (40K tokens)
3. Multi-turn conversation (10+ turns)
4. Code generation

**Compare Q4 vs Q5 outputs**:
- Accuracy
- Coherence
- Hallucinations
- Reasoning depth

## Memory Bandwidth Analysis

### Q5 Current (21GB model + 1.9GB cache = 23GB)
**Bottleneck**: Memory bandwidth reading KV cache
- 7900 XTX: 960 GB/s bandwidth
- With 50K context: ~6.9 tok/s

### Q4 Expected (17GB model + 1.9GB cache = 19GB)
**Same context (50K)**:
- Model is smaller → faster weight loading
- KV cache same size → same bandwidth for attention
- **Expected**: 7-8 tok/s (10-15% improvement)

**Larger context (100K)**:
- KV cache doubles (1.9GB → 4GB)
- Attention bandwidth doubles
- **Expected**: 3-4 tok/s (bandwidth saturation)

## When to Use Each

### Use Q5_K_XL When:
- ✅ Quality is critical (reasoning, accuracy)
- ✅ Context fits comfortably in 95K
- ✅ Single-document analysis
- ✅ Don't need long conversation history

### Use Q4_K_XL When:
- ✅ Context >80K needed (agentic workflows)
- ✅ Multiple documents or long conversations
- ✅ Speed more important than quality
- ✅ Can tolerate some quality degradation
- ✅ Want VRAM headroom for future expansion

## Next Steps

1. **First**: Test optimized Q5 (64GB cache, 4096 batch)
   - Establish best Q5 baseline
   - Document improvements

2. **Then**: Test Q4 with same params
   - Compare 50K context performance
   - Test 100K context (Q5 can't do this)
   - Assess quality

3. **Decision**: Choose model based on:
   - Throughput needs
   - Context size requirements
   - Quality tolerance
   - Agentic workload complexity

## Files to Create

- `run_llama_q4.sh` - Startup script for Q4 model
- `benchmark_q4_50k_results.jsonl` - Q4 performance at 50K
- `benchmark_q4_100k_results.jsonl` - Q4 performance at 100K
- `Q4_QUALITY_ASSESSMENT.md` - Qualitative comparison
