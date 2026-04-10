# Plan: Serving IQuest-Coder-V1-14B-Thinking on macbook2

**Model**: IQuestLab/IQuest-Coder-V1-14B-Thinking
**Hardware**: macbook2 (Apple M2 Max 96GB RAM)
**Target Directory**: `~/LJ-asi-mlx/models/`

---

## Executive Summary

**Recommended Approach**: Use **vllm-mlx** with MLX-converted model

**Why vllm-mlx over vllm-metal:**
1. Native MLX integration - no PyTorch dependency overhead
2. Standalone installation with uv/pip - simpler than vllm-metal's install.sh
3. Direct CLI (`vllm-mlx serve`) - cleaner integration
4. Active development with comprehensive documentation
5. Both support required parsers (reasoning + tool calling)

---

## Comparison: vllm-metal vs vllm-mlx

| Feature | vllm-metal | vllm-mlx |
|---------|-----------|----------|
| **Installation** | `curl install.sh \| bash` (creates ~/.venv-vllm-metal) | `uv pip install git+https://github.com/waybarrios/vllm-mlx.git` |
| **Model Format** | HuggingFace (PyTorch) + MLX hybrid | Pure MLX tensor format |
| **Reasoning Parser** | Via vLLM core | Built-in (`--reasoning-parser qwen3`) |
| **Tool Parser** | Via vLLM core | Built-in (`--tool-call-parser qwen`) |
| **API Compatibility** | OpenAI-compatible | OpenAI + Anthropic-compatible |
| **Installation Size** | Full vLLM + plugin | Minimal (MLX-only) |
| **Dependencies** | PyTorch + MLX | MLX only |

---

## Step-by-Step Implementation Plan

### Step 1: Install vllm-mlx

```bash
cd ~/LJ-asi-mlx
uv venv .venv-vllm-mlx
source .venv-vllm-mlx/bin/activate
uv pip install -e ./vllm-mlx
```

Or install CLI tool system-wide:
```bash
uv tool install git+https://github.com/waybarrios/vllm-mlx.git
```

### Step 2: Convert Model to MLX Format

The model needs to be downloaded and converted to MLX "tensor" format:

```bash
cd ~/LJ-asi-mlx
uv run python -c "
from mlx_lm import convert
convert(
    hf_path='IQuestLab/IQuest-Coder-V1-14B-Thinking',
    mlx_path='models/IQuest-Coder-V1-14B-Thinking-MLX',
    quantize=True,
    q_bits=4,
    q_group_size=64
)
"
```

**Note**: This will:
1. Download the model from HuggingFace (if not cached)
2. Convert weights to MLX format
3. Apply 4-bit quantization for memory efficiency

### Step 3: Start the Server

```bash
cd ~/LJ-asi-mlx
source .venv-vllm-mlx/bin/activate

vllm-mlx serve models/IQuest-Coder-V1-14B-Thinking-MLX \
  --port 8000 \
  --reasoning-parser qwen3 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen
```

**Key parameters:**
- `--reasoning-parser qwen3`: Extracts thinking from `<think>...</think>` tags
- `--enable-auto-tool-choice`: Enables tool/function calling
- `--tool-call-parser qwen`: Parses Qwen-style tool calls (XML or bracket format)

### Step 4: Test the Server

```bash
# Test with curl
curl http://localhost:8000/health

# Test reasoning response
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "What is 17 × 23?"}]
  }'
```

### Step 5: Integrate with Claude Code / OpenCode

```bash
export ANTHROPIC_BASE_URL=http://localhost:8000
export ANTHROPIC_API_KEY=not-needed
claude  # or opencode
```

---

## Alternative: vllm-metal Installation

If you prefer vllm-metal (for closer vLLM compatibility):

```bash
# Install via script
curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm-metal/main/install.sh | bash

# Activate environment
source ~/.venv-vllm-metal/bin/activate

# Run server (with MLX backend enabled)
VLLM_METAL_USE_MLX=1 vllm serve IQuestLab/IQuest-Coder-V1-14B-Thinking \
  --tool-parser qwen3_coder \
  --reasoning-parser qwen3 \
  --port 8000
```

---

## Parser Compatibility

| vLLM Parser | vllm-mlx Equivalent | Status |
|-------------|---------------------|--------|
| `--tool-parser qwen3_coder` | `--tool-call-parser qwen` | Compatible |
| `--reasoning-parser qwen3` | `--reasoning-parser qwen3` | Identical |

**Note**: The `qwen3_coder` parser in vLLM is essentially the Qwen tool parser with coding-specific training. The `qwen` parser in vllm-mlx handles the same format.

---

## Memory Requirements

| Quantization | Model Size | Estimated RAM |
|--------------|------------|---------------|
| 4-bit | ~8 GB | ~12 GB (with KV cache) |
| 8-bit | ~15 GB | ~20 GB (with KV cache) |
| Unquantized | ~28 GB | ~35 GB (with KV cache) |

On M2 Max 96GB, all options are viable. 4-bit recommended for faster inference.

---

## Next Steps

1. **Confirm approach**: Choose vllm-mlx (recommended) or vllm-metal
2. **Run installation**: Execute Step 1 commands
3. **Convert model**: Run Step 2 (takes 5-15 minutes depending on internet)
4. **Start server**: Run Step 3 and verify with Step 4
5. **Benchmark**: Run context benchmarks similar to llama.cpp tests

---

## References

- vllm-mlx: https://github.com/waybarrios/vllm-mlx
- vllm-metal: https://github.com/vllm-project/vllm-metal
- IQuest-Coder model: https://huggingface.co/IQuestLab/IQuest-Coder-V1-14B-Thinking
