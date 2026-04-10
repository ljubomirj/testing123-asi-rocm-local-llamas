#!/usr/bin/env python3
"""
Long-Context Benchmark for LLM Servers - MacBook Edition

Uses only stdlib (no requests dependency).
Designed for comparing macbook2 (Apple M2 Max 96GB) vs gigul2 (AMD 7900 XTX 24GB).

Features:
- Crash detection: detects LM Studio model crashes (swapaxes, exit code null, etc.)
- Auto-reload: uses `lms` CLI to unload/reload crashed models
- Single-message context: combines prefill+prompt into one user message
  (avoids multi-turn crashes on some backends)

Usage:
    python3 bench_longcontext_macbook.py --base http://localhost:1234 --model zai-org/glm-4.7-flash
    python3 bench_longcontext_macbook.py --base http://localhost:1234 --model zai-org/glm-4.7-flash --runs 1
"""

import argparse
import json
import subprocess
import time
import urllib.request
import urllib.error
import platform
import sys
from typing import Optional, Tuple

# --- LM Studio model reload via lms CLI ---

LMS_MODEL_PATH = "zai-org/glm-4.7-flash"
LMS_CONTEXT_LENGTH = 32768
MAX_RELOAD_ATTEMPTS = 3
RELOAD_POLL_INTERVAL = 10  # seconds between health checks after reload
RELOAD_POLL_MAX = 30  # max polls before giving up


def lms_reload_model(model_path: str = LMS_MODEL_PATH,
                     context_length: int = LMS_CONTEXT_LENGTH) -> bool:
    """Unload all models, then reload the target model via lms CLI.
    Returns True if the model came back up and responds to health checks."""
    print(f"\n  [RELOAD] Unloading all models...")
    sys.stdout.flush()
    try:
        subprocess.run(["lms", "unload", "--all"], capture_output=True, timeout=30)
    except Exception as e:
        print(f"  [RELOAD] Warning: unload failed: {e}")

    time.sleep(3)

    print(f"  [RELOAD] Loading {model_path} (ctx={context_length})...")
    sys.stdout.flush()
    try:
        result = subprocess.run(
            ["lms", "load", model_path,
             "--gpu", "max",
             "--context-length", str(context_length),
             "--identifier", model_path,
             "-y"],
            capture_output=True, text=True, timeout=300,
        )
        if result.returncode != 0:
            print(f"  [RELOAD] lms load failed (rc={result.returncode}): {result.stderr[:200]}")
            return False
        print(f"  [RELOAD] lms load completed")
    except subprocess.TimeoutExpired:
        print(f"  [RELOAD] lms load timed out after 300s")
        return False
    except Exception as e:
        print(f"  [RELOAD] lms load error: {e}")
        return False

    # Poll for health
    print(f"  [RELOAD] Waiting for model to respond...")
    sys.stdout.flush()
    for i in range(RELOAD_POLL_MAX):
        if _health_check(model_path):
            print(f"  [RELOAD] Model is UP (poll {i+1})")
            return True
        time.sleep(RELOAD_POLL_INTERVAL)

    print(f"  [RELOAD] Model did not come up after {RELOAD_POLL_MAX * RELOAD_POLL_INTERVAL}s")
    return False


def _health_check(model: str, base_url: str = "http://localhost:1234") -> bool:
    """Send a tiny request to check if the model responds."""
    url = f"{base_url}/v1/chat/completions"
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 4,
        "stream": False,
    }
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        resp = urllib.request.urlopen(req, timeout=60)
        body = json.loads(resp.read().decode())
        return "choices" in body
    except Exception:
        return False


def detect_crash(raw_response: str) -> bool:
    """Check if an SSE stream contains a model crash error."""
    crash_signals = [
        "swapaxes",
        "model has crashed",
        "Exit code: null",
        "Error in iterating prediction stream",
    ]
    return any(signal.lower() in raw_response.lower() for signal in crash_signals)


# --- Machine info ---

def get_machine_info() -> dict:
    """Collect machine information for comparison."""
    info = {
        "hostname": platform.node(),
        "platform": platform.platform(),
        "processor": platform.processor(),
        "machine": platform.machine(),
        "python_version": platform.python_version(),
    }
    if platform.system() == "Darwin":
        try:
            result = subprocess.run(
                ["sysctl", "-n", "hw.memsize"],
                capture_output=True, text=True, timeout=5,
            )
            mem_bytes = int(result.stdout.strip())
            info["ram_gb"] = mem_bytes / (1024**3)
        except Exception:
            pass
        try:
            result = subprocess.run(
                ["sysctl", "-n", "machdep.cpu.brand_string"],
                capture_output=True, text=True, timeout=5,
            )
            info["cpu"] = result.stdout.strip()
        except Exception:
            pass
    return info


# --- Text generation ---

def generate_text(num_tokens: int, topic: str = "technology") -> str:
    """Generate coherent text of approximately num_tokens tokens."""
    chars_needed = num_tokens * 4

    templates = [
        "The evolution of {topic} has transformed modern society in unprecedented ways. ",
        "Researchers continue to explore new frontiers in {topic}, pushing boundaries daily. ",
        "Industry leaders emphasize the importance of {topic} for future innovation. ",
        "Academic institutions worldwide are investing heavily in {topic} education programs. ",
        "The practical applications of {topic} extend across multiple sectors and industries. ",
        "Experts predict that {topic} will revolutionize how we approach complex problems. ",
        "Historical analysis shows that {topic} has undergone several paradigm shifts. ",
        "Current debates surrounding {topic} focus on ethical implications and societal impact. ",
        "Emerging trends in {topic} suggest accelerating development in the coming decade. ",
        "Collaborative efforts in {topic} research have yielded remarkable breakthroughs recently. ",
    ]

    text = f"# Context Document: Overview of {topic.title()}\n\n"
    text += f"This document provides comprehensive background information about {topic}.\n\n"

    section = 1
    while len(text) < chars_needed:
        text += f"\n## Section {section}: Advanced Topics\n\n"
        for template in templates:
            text += template.format(topic=topic)
            if len(text) >= chars_needed:
                break
        section += 1

    return text[:chars_needed]


def create_prompt(num_tokens: int, task: str = "analysis") -> str:
    """Generate a prompt of approximately num_tokens tokens."""
    chars_needed = num_tokens * 4

    prompt = f"Based on the context provided above, please perform a detailed {task}. "
    prompt += "Consider the following aspects: "

    aspects = [
        "historical development and key milestones",
        "current state-of-the-art approaches and methodologies",
        "technical challenges and proposed solutions",
        "practical applications in various domains",
        "future research directions and open questions",
        "comparative analysis with alternative approaches",
        "scalability considerations and performance metrics",
        "integration strategies with existing systems",
        "cost-benefit analysis and resource requirements",
        "ethical implications and societal impact",
    ]

    while len(prompt) < chars_needed:
        for aspect in aspects:
            prompt += f"\n- {aspect.title()}: Provide comprehensive analysis with specific examples and evidence. "
            if len(prompt) >= chars_needed:
                break

    return prompt[:chars_needed]


# --- HTTP helpers ---

def http_post_json(url: str, payload: dict, timeout: int = 600) -> dict:
    """POST JSON and return parsed response."""
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:500]
        raise RuntimeError(f"HTTP {e.code}: {body}") from e


def http_post_stream_raw(url: str, payload: dict, timeout: int = 600) -> str:
    """POST JSON, read the entire streaming response as a string.
    Returns the raw response body (for crash detection)."""
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        return resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:500]
        return f"event: error\ndata: {body}"


def parse_sse_content(raw: str) -> Tuple[int, str]:
    """Parse SSE lines and extract content + reasoning_content chars.
    Returns (total_chars, concatenated_text)."""
    total = 0
    parts = []
    for line in raw.split("\n"):
        line = line.strip()
        if not line.startswith("data: ") or line == "data: [DONE]":
            continue
        try:
            data = json.loads(line[6:])
            if "choices" in data and len(data["choices"]) > 0:
                delta = data["choices"][0].get("delta", {})
                content = delta.get("content", "") or delta.get("reasoning_content", "")
                if content:
                    total += len(content)
                    parts.append(content)
        except (json.JSONDecodeError, KeyError, IndexError):
            continue
    return total, "".join(parts)


def maybe_parse_json_arg(raw: Optional[str], arg_name: str) -> Optional[dict]:
    """Parse an optional JSON object argument."""
    if not raw:
        return None
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise ValueError(f"{arg_name} must decode to a JSON object")
    return value


def build_chat_payload(
    model: str,
    system: str,
    user: str,
    max_tokens: int,
    stream: bool,
    assistant_prefill: Optional[str] = None,
    chat_template_kwargs: Optional[dict] = None,
) -> dict:
    """Construct a chat completions payload with optional assistant prefill."""
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]
    if assistant_prefill is not None:
        messages.append({"role": "assistant", "content": assistant_prefill})

    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "stream": stream,
    }
    if chat_template_kwargs is not None:
        payload["chat_template_kwargs"] = chat_template_kwargs
    return payload


def strip_prefill_prefix(text: str, assistant_prefill: Optional[str]) -> Tuple[int, str]:
    """Remove assistant-prefill text echoed back by the server, if present."""
    if assistant_prefill and text.startswith(assistant_prefill):
        stripped = text[len(assistant_prefill):]
        return len(stripped), stripped
    return len(text), text


# --- Measurement ---

def measure_request(
    url: str,
    model: str,
    system: str,
    user: str,
    max_tokens: int = 512,
    prefill_context: Optional[str] = None,
    assistant_prefill: Optional[str] = None,
    chat_template_kwargs: Optional[dict] = None,
) -> Tuple[Optional[float], Optional[float], int, float, str, Optional[float], bool]:
    """
    Measure TTFT, throughput, and total time for a request.

    Returns:
        (ttft, chars_per_sec, response_chars, total_time, response_text, prefill_time, crashed)
    """
    endpoint = f"{url}/v1/chat/completions"
    prefill_time = None

    # Step 1: Prefill context if provided (separate request to warm cache)
    if prefill_context:
        print(f"  Prefilling context ({len(prefill_context)} chars, ~{len(prefill_context)//4} tokens)...")
        sys.stdout.flush()
        prefill_start = time.time()

        prefill_payload = build_chat_payload(
            model=model,
            system=system,
            user=prefill_context,
            max_tokens=1,
            stream=False,
            chat_template_kwargs=chat_template_kwargs,
        )

        try:
            http_post_json(endpoint, prefill_payload, timeout=600)
            prefill_time = time.time() - prefill_start
            print(f"  Context prefilled in {prefill_time:.2f}s")
        except Exception as e:
            prefill_time = time.time() - prefill_start
            err_str = str(e)
            if detect_crash(err_str):
                print(f"  CRASH during prefill after {prefill_time:.2f}s: {err_str[:100]}")
                return None, None, 0, 0, "", prefill_time, True
            print(f"  Warning: Context prefill failed after {prefill_time:.2f}s: {err_str[:100]}")

    # Step 2: Send actual prompt and measure
    # Combine context + prompt into single user message to avoid multi-turn
    # issues (some models/backends crash with consecutive user messages)
    if prefill_context:
        combined_user = prefill_context + "\n\n---\n\n" + user
    else:
        combined_user = user

    print(f"  Sending prompt ({len(combined_user)} chars, ~{len(combined_user)//4} tokens)...")
    sys.stdout.flush()

    payload = build_chat_payload(
        model=model,
        system=system,
        user=combined_user,
        max_tokens=max_tokens,
        stream=True,
        assistant_prefill=assistant_prefill,
        chat_template_kwargs=chat_template_kwargs,
    )

    t0 = time.time()

    raw = http_post_stream_raw(endpoint, payload, timeout=1800)
    t1 = time.time()
    dt = t1 - t0

    # Check for crash
    if detect_crash(raw):
        print(f"  CRASH detected after {dt:.1f}s")
        return None, None, 0, dt, "", prefill_time, True

    # Parse content from SSE
    n_chars, response_text = parse_sse_content(raw)
    n_chars, response_text = strip_prefill_prefix(response_text, assistant_prefill)

    # Estimate TTFT: we can't get per-chunk timing from raw read, so use
    # a heuristic: if we got content, TTFT ~ total_time - (n_chars / overall_rate)
    # For a better TTFT we'd need per-chunk streaming, but crash detection
    # requires reading the full response. Use the total time as TTFT proxy
    # when content is small relative to prompt processing.
    # Actually, let's do a hybrid: stream with crash detection.
    # For now, approximate TTFT from the data we have.
    if n_chars > 0:
        # Rough estimate: generation takes n_chars/rate seconds at the end
        # TTFT is the gap before generation starts
        # Without per-chunk timing, use total_time as upper bound for TTFT
        # and compute chars_per_sec from the whole request
        chars_per_sec = n_chars / dt if dt > 0 else None
        # TTFT approximation: for streaming we'd track first chunk time
        # Since we read all at once, we don't have true TTFT
        # Use None to indicate we can't measure it with raw read
        ttft = None
    else:
        chars_per_sec = None
        ttft = None

    return ttft, chars_per_sec, n_chars, dt, response_text, prefill_time, False


def measure_request_streaming(
    url: str,
    model: str,
    system: str,
    user: str,
    max_tokens: int = 512,
    prefill_context: Optional[str] = None,
    assistant_prefill: Optional[str] = None,
    chat_template_kwargs: Optional[dict] = None,
) -> Tuple[Optional[float], Optional[float], int, float, str, Optional[float], bool]:
    """
    Measure TTFT, throughput, and total time with true streaming + crash detection.

    Reads the response incrementally for accurate TTFT measurement,
    and checks accumulated response for crash signals at the end.

    Returns:
        (ttft, chars_per_sec, response_chars, total_time, response_text, prefill_time, crashed)
    """
    endpoint = f"{url}/v1/chat/completions"
    prefill_time = None

    # Step 1: Prefill context if provided
    if prefill_context:
        print(f"  Prefilling context ({len(prefill_context)} chars, ~{len(prefill_context)//4} tokens)...")
        sys.stdout.flush()
        prefill_start = time.time()

        prefill_payload = build_chat_payload(
            model=model,
            system=system,
            user=prefill_context,
            max_tokens=1,
            stream=False,
            chat_template_kwargs=chat_template_kwargs,
        )

        try:
            http_post_json(endpoint, prefill_payload, timeout=600)
            prefill_time = time.time() - prefill_start
            print(f"  Context prefilled in {prefill_time:.2f}s")
        except Exception as e:
            prefill_time = time.time() - prefill_start
            err_str = str(e)
            if detect_crash(err_str):
                print(f"  CRASH during prefill after {prefill_time:.2f}s: {err_str[:100]}")
                return None, None, 0, 0, "", prefill_time, True
            print(f"  Warning: Context prefill failed after {prefill_time:.2f}s: {err_str[:100]}")

    # Step 2: Combined context+prompt in single user message
    if prefill_context:
        combined_user = prefill_context + "\n\n---\n\n" + user
    else:
        combined_user = user

    print(f"  Sending prompt ({len(combined_user)} chars, ~{len(combined_user)//4} tokens)...")
    sys.stdout.flush()

    payload = build_chat_payload(
        model=model,
        system=system,
        user=combined_user,
        max_tokens=max_tokens,
        stream=True,
        assistant_prefill=assistant_prefill,
        chat_template_kwargs=chat_template_kwargs,
    )

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        endpoint, data=data, headers={"Content-Type": "application/json"}
    )

    t0 = time.time()
    first_token_t = None
    response_text = ""
    n_chars = 0
    raw_lines = []
    remaining_assistant_prefill = assistant_prefill or ""

    try:
        try:
            resp = urllib.request.urlopen(req, timeout=1800)
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")[:500]
            if detect_crash(body):
                print(f"  CRASH on HTTP error: {body[:100]}")
                return None, None, 0, time.time() - t0, "", prefill_time, True
            print(f"  HTTP ERROR {e.code}: {body[:100]}")
            return None, None, 0, time.time() - t0, "", prefill_time, False

        buffer = b""
        while True:
            chunk = resp.read(1024)
            if not chunk:
                break
            buffer += chunk
            while b"\n" in buffer:
                line_bytes, buffer = buffer.split(b"\n", 1)
                line_str = line_bytes.decode("utf-8", errors="replace").strip()
                if not line_str:
                    continue

                raw_lines.append(line_str)

                if not line_str.startswith("data: "):
                    # Could be "event: error" etc
                    continue

                if line_str == "data: [DONE]":
                    break

                try:
                    event = json.loads(line_str[6:])
                    if "choices" in event and len(event["choices"]) > 0:
                        delta = event["choices"][0].get("delta", {})
                        content = delta.get("content", "") or delta.get("reasoning_content", "")
                        if content:
                            if remaining_assistant_prefill:
                                if remaining_assistant_prefill.startswith(content):
                                    remaining_assistant_prefill = remaining_assistant_prefill[len(content):]
                                    content = ""
                                elif content.startswith(remaining_assistant_prefill):
                                    content = content[len(remaining_assistant_prefill):]
                                    remaining_assistant_prefill = ""
                                else:
                                    remaining_assistant_prefill = ""
                            if not content:
                                continue
                            if first_token_t is None:
                                first_token_t = time.time()
                            n_chars += len(content)
                            response_text += content
                except (json.JSONDecodeError, KeyError, IndexError):
                    continue

        t1 = time.time()
        dt = t1 - t0

        # Check accumulated response for crash signals
        full_raw = "\n".join(raw_lines)
        if detect_crash(full_raw):
            print(f"  CRASH detected in stream after {dt:.1f}s")
            return None, None, 0, dt, "", prefill_time, True

        ttft = (first_token_t - t0) if first_token_t else None
        chars_per_sec = (n_chars / dt) if dt > 0 and n_chars > 0 else None

        return ttft, chars_per_sec, n_chars, dt, response_text, prefill_time, False

    except Exception as e:
        dt = time.time() - t0
        err_str = str(e)
        if detect_crash(err_str):
            print(f"  CRASH (exception): {err_str[:100]}")
            return None, None, 0, dt, "", prefill_time, True
        print(f"  ERROR: {err_str[:200]}")
        return None, None, 0, dt, "", prefill_time, False


# --- Main ---

def main():
    parser = argparse.ArgumentParser(
        description="Long-context benchmark for LLM servers (stdlib, no dependencies)"
    )
    parser.add_argument(
        "--base", default="http://localhost:1234",
        help="Base URL of the server (default: http://localhost:1234)",
    )
    parser.add_argument(
        "--model", default="zai-org/glm-4.7-flash",
        help="Model name (default: zai-org/glm-4.7-flash)",
    )
    parser.add_argument(
        "--lms-model-path", default=LMS_MODEL_PATH,
        help=f"Model path for lms reload (default: {LMS_MODEL_PATH})",
    )
    parser.add_argument(
        "--prefill-tokens", type=int, default=40000,
        help="Number of tokens to prefill in context (default: 40000)",
    )
    parser.add_argument(
        "--prompt-tokens", default="10000,15000",
        help="Comma-separated list of prompt sizes in tokens (default: 10000,15000)",
    )
    parser.add_argument(
        "--max-tokens", type=int, default=512,
        help="Maximum tokens to generate (default: 512)",
    )
    parser.add_argument(
        "--runs", type=int, default=3,
        help="Number of runs per test (default: 3)",
    )
    parser.add_argument(
        "--output", default="benchmark_longcontext_macbook2.jsonl",
        help="Output JSONL file (default: benchmark_longcontext_macbook2.jsonl)",
    )
    parser.add_argument(
        "--no-prefill", action="store_true",
        help="Skip context prefilling (compare with/without)",
    )
    parser.add_argument(
        "--backend-label", default="lmstudio-mlx",
        help="Backend label for results (default: lmstudio-mlx)",
    )
    parser.add_argument(
        "--context-length", type=int, default=LMS_CONTEXT_LENGTH,
        help=f"Context length for lms reload (default: {LMS_CONTEXT_LENGTH})",
    )
    parser.add_argument(
        "--assistant-prefill", default=None,
        help="Optional assistant prefix to prefill before generation",
    )
    parser.add_argument(
        "--chat-template-kwargs-json", default=None,
        help="Optional JSON object for chat_template_kwargs",
    )

    args = parser.parse_args()

    prompt_sizes = [int(x.strip()) for x in args.prompt_tokens.split(",")]
    machine_info = get_machine_info()
    chat_template_kwargs = maybe_parse_json_arg(
        args.chat_template_kwargs_json,
        "--chat-template-kwargs-json",
    )

    print("=" * 60)
    print("Long-Context Benchmark - MacBook Edition")
    print("=" * 60)
    print(f"  Machine: {machine_info.get('hostname', 'unknown')}")
    print(f"  Platform: {machine_info.get('platform', 'unknown')}")
    print(f"  CPU: {machine_info.get('cpu', machine_info.get('processor', 'unknown'))}")
    if isinstance(machine_info.get("ram_gb"), (int, float)):
        print(f"  RAM: {machine_info['ram_gb']:.0f} GB")
    else:
        print(f"  RAM: unknown")
    print(f"  Endpoint: {args.base}")
    print(f"  Model: {args.model}")
    print(f"  Backend: {args.backend_label}")
    if not args.no_prefill:
        print(f"  Context prefill: {args.prefill_tokens} tokens (~{args.prefill_tokens * 4} chars)")
    else:
        print(f"  Context prefill: DISABLED (empty context test)")
    print(f"  Prompt sizes: {prompt_sizes} tokens")
    print(f"  Runs per size: {args.runs}")
    print(f"  Max tokens: {args.max_tokens}")
    print(f"  Output: {args.output}")
    print(f"  Auto-reload: lms reload on crash (model={args.lms_model_path})")
    if args.assistant_prefill is not None:
        print(f"  Assistant prefill: {args.assistant_prefill!r}")
    if chat_template_kwargs is not None:
        print(f"  Chat template kwargs: {json.dumps(chat_template_kwargs, sort_keys=True)}")
    print()

    # Generate context once (reused across tests)
    context = None
    if not args.no_prefill:
        print("Generating context text...")
        context = generate_text(args.prefill_tokens, topic="artificial intelligence")
        print(f"  Generated {len(context)} chars (~{len(context)//4} tokens)")
        print()

    system_prompt = "You are a helpful AI assistant with expertise in technology and research."

    results = []
    crash_count = 0
    benchmark_start = time.time()

    for prompt_tokens in prompt_sizes:
        print("=" * 60)
        print(f"Testing with {prompt_tokens} token prompts")
        if not args.no_prefill:
            print(f"  + {args.prefill_tokens} tokens of prefilled context")
            print(f"  = ~{args.prefill_tokens + prompt_tokens} total active context")
        print("=" * 60)
        print()

        for run in range(1, args.runs + 1):
            run_start = time.time()
            print(f"Run {run}/{args.runs} (elapsed: {run_start - benchmark_start:.0f}s):")

            prompt = create_prompt(prompt_tokens, task=f"analysis run {run}")

            ttft, cps, n_chars, total_time, response, prefill_time, crashed = \
                measure_request_streaming(
                    url=args.base,
                    model=args.model,
                    system=system_prompt,
                    user=prompt,
                    max_tokens=args.max_tokens,
                    prefill_context=context,
                    assistant_prefill=args.assistant_prefill,
                    chat_template_kwargs=chat_template_kwargs,
                )

            # Handle crash: reload and retry once
            if crashed:
                crash_count += 1
                print(f"  [CRASH #{crash_count}] Model crashed, attempting reload...")
                sys.stdout.flush()

                reloaded = False
                for attempt in range(1, MAX_RELOAD_ATTEMPTS + 1):
                    print(f"  [RELOAD attempt {attempt}/{MAX_RELOAD_ATTEMPTS}]")
                    if lms_reload_model(args.lms_model_path, args.context_length):
                        reloaded = True
                        break

                if reloaded:
                    print(f"  [RETRY] Re-running run {run}...")
                    ttft, cps, n_chars, total_time, response, prefill_time, crashed = \
                        measure_request_streaming(
                            url=args.base,
                            model=args.model,
                            system=system_prompt,
                            user=prompt,
                            max_tokens=args.max_tokens,
                            prefill_context=context,
                            assistant_prefill=args.assistant_prefill,
                            chat_template_kwargs=chat_template_kwargs,
                        )
                    if crashed:
                        print(f"  [ABORT] Crashed again after reload. "
                              f"Context size {(args.prefill_tokens if not args.no_prefill else 0) + prompt_tokens} "
                              f"tokens exceeds model limit. Skipping remaining runs.")
                        # Record the crash as a result
                        result = {
                            "machine": machine_info.get("hostname", "unknown"),
                            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
                            "run_id": run,
                            "prompt_tokens": prompt_tokens,
                            "prefill_tokens": args.prefill_tokens if not args.no_prefill else 0,
                            "total_context_tokens": (args.prefill_tokens if not args.no_prefill else 0) + prompt_tokens,
                            "max_tokens": args.max_tokens,
                            "ttft_sec": None,
                            "chars_per_sec": None,
                            "tokens_per_sec": None,
                            "response_chars": 0,
                            "response_tokens": 0,
                            "total_time_sec": total_time,
                            "prefill_time_sec": prefill_time,
                            "model": args.model,
                            "backend": args.backend_label,
                            "machine_info": machine_info,
                            "crashed": True,
                            "crash_reason": "context_limit_exceeded",
                        }
                        results.append(result)
                        # Skip to next prompt size
                        break
                else:
                    print(f"  [FATAL] Could not reload model. Aborting benchmark.")
                    sys.exit(1)

            result = {
                "machine": machine_info.get("hostname", "unknown"),
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
                "run_id": run,
                "prompt_tokens": prompt_tokens,
                "prefill_tokens": args.prefill_tokens if not args.no_prefill else 0,
                "total_context_tokens": (args.prefill_tokens if not args.no_prefill else 0) + prompt_tokens,
                "max_tokens": args.max_tokens,
                "ttft_sec": ttft,
                "chars_per_sec": cps,
                "tokens_per_sec": (cps / 4) if cps else None,
                "response_chars": n_chars,
                "response_tokens": n_chars // 4,
                "total_time_sec": total_time,
                "prefill_time_sec": prefill_time,
                "model": args.model,
                "backend": args.backend_label,
                "assistant_prefill": args.assistant_prefill,
                "chat_template_kwargs": chat_template_kwargs,
                "machine_info": machine_info,
                "crashed": False,
            }

            results.append(result)

            # Save incrementally
            with open(args.output, "w") as f:
                for r in results:
                    f.write(json.dumps(r) + "\n")

            if ttft is not None:
                print(f"  TTFT: {ttft:.3f}s")
            else:
                print(f"  TTFT: N/A")
            if cps is not None:
                print(f"  Throughput: {cps:.1f} chars/sec (~{cps/4:.1f} tok/s)")
            else:
                print(f"  Throughput: N/A")
            print(f"  Total time: {total_time:.3f}s")
            print(f"  Generated: {n_chars} chars (~{n_chars//4} tokens)")
            if prefill_time:
                print(f"  Prefill time: {prefill_time:.2f}s")
            print()
            sys.stdout.flush()

        # Calculate averages for this prompt size
        valid_results = [
            r for r in results
            if r["prompt_tokens"] == prompt_tokens
            and r.get("ttft_sec") is not None
            and not r.get("crashed", False)
        ]
        if valid_results:
            avg_ttft = sum(r["ttft_sec"] for r in valid_results) / len(valid_results)
            avg_throughput = sum(r["chars_per_sec"] for r in valid_results) / len(valid_results)
            avg_tok_s = avg_throughput / 4

            print(f"Average for {prompt_tokens} token prompts:")
            print(f"  TTFT: {avg_ttft:.3f}s")
            print(f"  Throughput: {avg_throughput:.1f} chars/s (~{avg_tok_s:.1f} tok/s)")
            print()

    benchmark_end = time.time()
    total_benchmark_time = benchmark_end - benchmark_start

    # Save final results
    print("=" * 60)
    print(f"Saving results to: {args.output}")
    with open(args.output, "w") as f:
        for result in results:
            f.write(json.dumps(result) + "\n")

    print(f"Total runs: {len(results)}")
    print(f"Total crashes: {crash_count}")
    print(f"Total benchmark time: {total_benchmark_time:.0f}s ({total_benchmark_time/60:.1f} min)")
    print()

    # Summary
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)

    for prompt_tokens in prompt_sizes:
        valid = [
            r for r in results
            if r["prompt_tokens"] == prompt_tokens
            and r.get("ttft_sec") is not None
            and not r.get("crashed", False)
        ]
        crashed_runs = [
            r for r in results
            if r["prompt_tokens"] == prompt_tokens and r.get("crashed", False)
        ]
        total_ctx = (args.prefill_tokens if not args.no_prefill else 0) + prompt_tokens

        if crashed_runs and not valid:
            print(f"  Prompt {prompt_tokens} tokens (total ~{total_ctx} tokens): CRASHED (MLX limit)")
        elif valid:
            avg_ttft = sum(r["ttft_sec"] for r in valid) / len(valid)
            avg_tps = sum(r["tokens_per_sec"] for r in valid) / len(valid)
            print(f"  Prompt {prompt_tokens} tokens (total context ~{total_ctx} tokens):")
            print(f"    TTFT: {avg_ttft:.3f}s")
            print(f"    Throughput: {avg_tps:.1f} tok/s")

    print()
    print("Benchmark complete!")
    print(f"Results saved to: {args.output}")
    print()


if __name__ == "__main__":
    main()
