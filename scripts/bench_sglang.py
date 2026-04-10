import json, time, argparse, requests, os
from pathlib import Path

def stream_chat(url, model, system, user, max_tokens=32768, verbose=0):
    t0 = time.time()
    first_token_t = None
    n_chars = 0
    response_parts = []

    payload = {
        "model": model,
        "stream": True,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "max_tokens": max_tokens,
        "temperature": 0.0,
    }

    with requests.post(url, json=payload, stream=True, timeout=600) as r:
        r.raise_for_status()
        for line in r.iter_lines(decode_unicode=True):
            if not line:
                continue
            if line.startswith("data: "):
                line = line[len("data: "):]
            if line.strip() == "[DONE]":
                break

            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            # OpenAI-style streaming deltas (content / reasoning / tool calls)
            delta = event["choices"][0].get("delta", {})
            chunks = []
            content = delta.get("content")
            if isinstance(content, str):
                chunks.append(content)
            reasoning = delta.get("reasoning_content") or delta.get("reasoning")
            if isinstance(reasoning, str):
                chunks.append(reasoning)
            tool_calls = delta.get("tool_calls")
            if isinstance(tool_calls, list):
                for call in tool_calls:
                    if not isinstance(call, dict):
                        continue
                    fn = call.get("function") or {}
                    if isinstance(fn, dict):
                        name = fn.get("name")
                        args = fn.get("arguments")
                        if isinstance(name, str):
                            chunks.append(name)
                        if isinstance(args, str):
                            chunks.append(args)

            chunk = "".join(chunks)
            if chunk:
                if first_token_t is None:
                    first_token_t = time.time()
                n_chars += len(chunk)
                if verbose:
                    response_parts.append(chunk)

    t1 = time.time()
    ttft = (first_token_t - t0) if first_token_t else None
    dt = t1 - t0
    cps = (n_chars / dt) if dt > 0 else None
    response_text = "".join(response_parts) if verbose else ""
    return ttft, cps, n_chars, dt, response_text

def _read_text(path):
    return Path(path).read_text(encoding="utf-8")

def _get_env_int(name, default):
    val = os.getenv(name)
    if not val:
        return default
    try:
        return int(val)
    except ValueError:
        return default

def _extend_to_len(text, target_len):
    if target_len is None or target_len <= 0:
        return text
    if len(text) >= target_len:
        return text[:target_len]
    filler = "\nLorem ipsum dolor sit amet."
    out = text
    while len(out) < target_len:
        out += filler
    return out[:target_len]

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://192.168.1.251:8000")
    #ap.add_argument("--base", default="http://127.0.0.1:58416")
    ap.add_argument("--model", default="glm-4.7-flash")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--max-tokens", type=int, default=_get_env_int("BENCH_MAX_TOKENS", 4096))
    ap.add_argument("--prompt-len", type=int, default=_get_env_int("BENCH_PROMPT_LEN", 0))
    ap.add_argument("--prompt-file", default=None)
    ap.add_argument("--system-file", default=None)
    ap.add_argument("-v", action="count", default=0, help="print responses (-vv prints prompts too)")
    args = ap.parse_args()

    url = args.base.rstrip("/") + "/v1/chat/completions"

    # Make the prefix big to test caching effects
    system = """
You are a concise assistant. Answer with only the final answer.
This is a starting point. Add your own conventions, style, and rules as you figure out what works.
"""
    user = """
Write one short sentence confirming you are alive. 
Then write a second sentence for the fun of it.
And then write as many sentences next, as there are sentences in this prompt, and add plus one extra sentence at the end for good luck.
"""
    if args.system_file:
        system = _read_text(args.system_file)
    if args.prompt_file:
        user = _read_text(args.prompt_file)
    user = _extend_to_len(user, args.prompt_len)
    print(f"Endpoint: {url}")
    print(f"Model:    {args.model}")
    print()

    for i in range(args.runs):
        run_user = user + ("\nAnd another sentence here." * i)
        if args.v >= 2:
            print("----- SYSTEM -----")
            print(system.rstrip())
            print("----- USER -----")
            print(run_user.rstrip())
        ttft, cps, n_chars, dt, response_text = stream_chat(
            url,
            args.model,
            system,
            run_user,
            max_tokens=args.max_tokens,
            verbose=args.v,
        )
        if args.v:
            print("----- RESPONSE -----")
            print(response_text.rstrip())
        ttft_s = f"{ttft:.3f}s" if ttft is not None else "NA"
        cps_s = f"{cps:.1f}" if cps is not None else "NA"
        print(f"Run {i+1}: TTFT={ttft_s}  chars/sec={cps_s}  chars={n_chars}  total={dt:.3f}s")

### Short run with small prompt:
### BENCH_MAX_TOKENS=30 BENCH_PROMPT_LEN=50 python3 bench_sglang.py -v --runs 1
### Use a custom prompt file:
### BENCH_PROMPT_FILE=/path/to/prompt.txt python3 bench_sglang.py -vv
### Custom system prompt too:
### BENCH_SYSTEM_FILE=/path/to/system.txt ./scripts/run_server_and_bench.sh
### Verbose:
### - -v prints responses
### - -vv prints system+user prompts and responses

### 4) Tiny benchmark script: TTFT + tokens/sec (streaming)
### Save as `bench_sglang.py` on your Mac or on gigul2:
### 
### Run it:
### python3 bench_sglang.py --base http://192.168.1.251:8000 --model glm-4.7-flash --runs 5
### 
### How to interpret results
### * **Run 1** will include “cold” effects (loading, compilation, cache population).
### * If SGLang prefix caching is hitting, you often see **Run 2/3 TTFT drop** *when the system prompt is identical*.

