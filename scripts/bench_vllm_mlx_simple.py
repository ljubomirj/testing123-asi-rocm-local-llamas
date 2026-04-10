#!/usr/bin/env python3
"""Simple benchmark for vLLM-MLX - test smaller contexts to find practical limit."""

import json
import time
import urllib.request

PROMPT_TEXT = "The quick brown fox jumps over the lazy dog. "

def test_context(url, total_tokens, prefill_tokens):
    """Test a specific context size."""
    prefill_chars = prefill_tokens * 4
    target_chars = total_tokens * 4

    prefill = (PROMPT_TEXT * ((prefill_chars // len(PROMPT_TEXT)) + 1))[:prefill_chars]

    messages = [{"role": "user", "content": f"Say hello"}]
    if prefill_tokens > 0:
        messages.insert(0, {"role": "system", "content": f"Context: {prefill}"})

    data = {
        "model": "default",
        "messages": messages,
        "max_tokens": 100,
        "stream": False
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )

    try:
        start = time.time()
        with urllib.request.urlopen(req, timeout=300) as response:
            result = json.loads(response.read().decode())
            elapsed = time.time() - start

        usage = result.get("usage", {})
        completion_tokens = usage.get("completion_tokens", 0)

        throughput = completion_tokens / elapsed if elapsed > 0 else 0
        return elapsed, throughput, None
    except Exception as e:
        return 0, 0, str(e)

url = "http://localhost:8081/v1/chat/completions"

# Wait for server
time.sleep(5)

print("Testing vLLM-MLX IQuest-Coder 8-bit on port 8081")
print("=" * 60)

tests = [
    (50, 0),
    (100, 0),
    (500, 0),
    (1000, 0),
    (2000, 0),
    (4000, 0),
    (8000, 0),
    (10000, 0),
    (12000, 10000),
    (15000, 10000),
]

print(f"{'Context':>10} {'Prefill':>10} {'TTFT':>10} {'Throughput':>12} {'Status'}")
print("-" * 60)

for total, prefill in tests:
    ttft, tp, err = test_context(url, total, prefill)
    if err:
        print(f"{total:>10,} {prefill:>10,} {'N/A':>10} {'N/A':>12} ERROR: {err[:50]}")
        break
    else:
        print(f"{total:>10,} {prefill:>10,} {ttft:>10.2f}s {tp:>10.1f} t/s  OK")
