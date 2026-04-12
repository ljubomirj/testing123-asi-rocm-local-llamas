# MiniMax-M2.5 JANG_2L on macbook2

**Date**: 2026-03-28

## Bottom Line

`JANGQ-AI/MiniMax-M2.5-JANG_2L` does load and generate on macbook2 with the existing `~/python3-venv/torch313` environment.

The missing piece was not a separate MLX fork. The required runtime is the `jang` package layered on top of MLX:

- `jang 2.2.0`
- `mlx 0.30.6`
- `mlx-lm 0.30.7`

That stack was already present in the venv and was sufficient to load the cached local model snapshot.

## Sources

- Hugging Face model card: <https://huggingface.co/JANGQ-AI/MiniMax-M2.5-JANG_2L>
- JANG runtime repo: <https://github.com/jjang-ai/jangq>

From those sources:

- `temp=1.0` is required; greedy `temp=0` can loop
- `top_p=0.95`, `top_k=40` are recommended
- JANG models need the JANG runtime rather than plain MLX loading

## Local Model Path

Used local snapshot path only, with no new download:

```text
/Users/ljubomir/.cache/huggingface/hub/models--JANGQ-AI--MiniMax-M2.5-JANG_2L/snapshots/6a2d1e1c9475a63961cfb17253436dbe5fd6fa65
```

The `models/huggingface/...` path resolves to the same cache directory.

## Model Facts From Local Config

- `model_type=minimax_m2`
- `max_position_embeddings=196608`
- `num_hidden_layers=62`
- `num_local_experts=256`
- `num_experts_per_tok=8`
- `jang_config.runtime.total_weight_gb=55.9`
- Disk footprint on this machine: about `63 GB`

## What Was Run

Offline local-path run in `~/python3-venv/torch313`:

```bash
source ~/python3-venv/torch313/bin/activate
export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1
python scripts/run_minimax_jang_example.py --repeat 2
```

The helper script is here:

- [run_minimax_jang_example.py](/Users/ljubomir/rocm-glm-4.7-flash/scripts/run_minimax_jang_example.py)

## Measured Results

Cold-load run:

- load time: about `19.8s` to `31.2s`
- first token on first short prompt after load: `17.75s`
- decode speed: about `0.52 tok/s`

Two prompts in one loaded process:

- run 1: first token `30.64s`, decode `0.51 tok/s`
- run 2: first token `5.86s`, decode `0.51 tok/s`

So the practical picture is:

- the model fits
- the loader works
- warm TTFT gets much better than cold TTFT
- steady decode remains very slow on macbook2, around `0.5 tok/s`

## Memory

Observed in the short measured run:

- peak memory footprint: `67894839232` bytes, about `67.9 GB`
- current `iogpu.wired_limit_mb` on this machine was `0`

So the example fit without raising the wired GPU limit to `88000`.

## Output Quality Note

The raw example prompt from the model card does generate, but it tended to continue in an odd templated style rather than producing a crisp one-line answer immediately. That does not change the runtime result: the core runtime stack works, but the model is not practically fast on this hardware in this configuration.

## Conclusion

This MiniMax JANG_2L setup is technically runnable on macbook2, but speed is not good enough to be attractive for interactive local use.
