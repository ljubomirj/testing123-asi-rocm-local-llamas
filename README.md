# Local LLMs on hardware I already own

This is a public notebook from an ongoing attempt to answer a simple question:
how much useful local AI can I get from machines that were not bought as an AI
cluster?

The machines are a 2023 MacBook Pro with an M2 Max and 96 GB of unified memory,
and a Linux desktop with an AMD Radeon RX 7900 XTX and 24 GB of VRAM. The Mac can
fit surprisingly large models. The Radeon can run the models that fit much
faster. Neither machine lets me ignore memory, context length, kernels, chat
templates, quantisation, or the occasional software adventure.

That is the interesting bit. A model card tells me what a model might do. These
notes are about what happened when I tried to make it do actual work.

## The two machines

| | M2 Max MacBook Pro | Radeon desktop |
|---|---|---|
| Memory | 96 GB unified | 24 GB VRAM plus system RAM |
| Main backends | Metal, MLX, llama.cpp, oMLX, ds4 | ROCm/HIP, Vulkan, llama.cpp |
| Best trait | Capacity and flexibility | Speed and memory bandwidth |
| Main irritation | Large models fit, then make me wait | Many stacks say AMD; fewer mean this AMD |
| Practical role | Big-model lab, long-context work, offline coding | Fast tests and inference for models that fit |

The short version is: capacity and speed are different resources. The Mac has
the larger room. The Radeon has the faster conveyor belt. Model architecture
decides which matters more.

## What I measure

I use three kinds of test because any one of them can lie by omission.

1. `llama-bench`-style prompt processing and text generation gives a clean
   engine-level speed measurement.
2. Forced-context tests measure time to first token and generation speed after
   15K, 30K, 50K, 110K, and sometimes much larger contexts.
3. A 92-problem LiveCodeBench subset checks whether a faster configuration can
   still write code rather than merely produce tokens enthusiastically.

The first lesson was mildly embarrassing and therefore useful: an empty-context
result of 100 tokens/s does not describe a coding agent carrying 50K tokens of
repository history. Early GLM-4.7-Flash tests fell from 94-112 tokens/s at tiny
context to 6.9 tokens/s at 50K and 4.4 tokens/s at 55K under Vulkan. The
[test analysis](results/LLAMA_CPP_TEST_ANALYSIS.md) is kept here partly as a
warning to my future self.

## ROCm changed the 7900 XTX from interesting to useful

On the same 7900 XTX and the same GLM-4.7-Flash workload, moving from Vulkan to
ROCm/HIP changed the result substantially:

| Effective context | Vulkan | ROCm/HIP | ROCm advantage |
|---:|---:|---:|---:|
| 20K | 15.3 tok/s | 39.2 tok/s | 2.6x |
| 50K | 6.9 tok/s | 21.8 tok/s | 3.2x |
| 55K | 4.4 tok/s | 16.2 tok/s | 3.7x |

The detailed runs are in
[the ROCm/Vulkan comparison](results/CONTEXT_RESULTS_GIGUL2.md). This was not a
small benchmark victory. It was the difference between watching text arrive and
forgetting what I had asked while waiting for it.

The AMD story remains untidy. `llama.cpp` has been the dependable base because
it runs almost everything I can squeeze into memory. SGLang and vLLM have more
attractive high-end paths, but RDNA 3 support often stops at a build gate, an
unsupported fused operation, or a kernel tested on MI-series hardware rather
than a consumer `gfx1100` card. I have spent enough time discovering which
meaning of "ROCm supported" a project uses.

## MoE models suit both machines unusually well

Mixture-of-Experts models store many parameters but activate a smaller fraction
for each token. That is a good match for the odd combination here: lots of
unified memory but modest compute on the Mac, and plenty of compute but only
24 GB of VRAM on the Radeon.

Qwen3.6-35B-A3B and Nemotron-Cascade-2-30B-A3B show the trade-off clearly.

| Machine and model | Short context | 50K context | LiveCodeBench pass@1 | Runtime |
|---|---:|---:|---:|---:|
| M2 Max, Qwen3.6 Q6 | 44.4 tok/s | 13.5 tok/s | 83.70% | 7.4 h |
| M2 Max, Nemotron Q6 | 57.7 tok/s | 16.4 tok/s | 81.52% | 2.3 h |
| 7900 XTX, Qwen3.6 IQ4_XS | 61.0 tok/s | 25.4 tok/s | 84.78% | 2.3 h |
| 7900 XTX, Nemotron IQ4_XS | 98.9 tok/s | 32.4 tok/s | 82.61% | 1.0 h |

Qwen solved two more problems out of every hundred or so. Nemotron returned
answers much sooner and did better on the hard slice in the Radeon run. There
is no universal winner hiding in those numbers. There is a model I choose when
I care most about the last few coding problems, and another when I am going to
sit in the loop with it.

See the full
[Qwen3.6 versus Nemotron comparison](results/COMPARISON_QWEN36_VS_NEMOTRON.md),
plus the individual [Mac Qwen](results/QWEN36_35B_A3B_MACBOOK2.md) and
[Radeon Qwen](results/QWEN36_35B_A3B_GIGUL2.md) reports.

## "Thinking" is a configuration, not a magic adjective

Nemotron produced one of the most useful results in the collection:

| Mode | LiveCodeBench pass@1 | Runtime |
|---|---:|---:|
| Thinking off | 50.00% | 1,580 s |
| Thinking on, unbounded 16K output | 77.17% | 17,148 s |
| Thinking on, 4K reasoning budget in 10K total | 81.52% | 8,146 s |

Turning reasoning off made it quick and much worse. Letting it think without a
practical budget made it slow and still worse than the bounded run. The middle
setting won on both quality and time.

Gemma 4 provided the reverse warning. The ggml-org Q8 model with non-thinking
requests scored 88.04% on the same subset. An Unsloth UD-Q8_K_XL run with
thinking enabled scored 20.65% and took 40,045 seconds. That is not a subtle
quantisation delta. It is a reminder to verify the chat template, reasoning
mode, and output shape before treating two filenames as comparable models.

The two reports are
[Gemma 4 non-thinking](results/MACBOOK2_GEMMA4_26B_A4B.md) and
[Gemma 4 thinking-on](results/MACBOOK2_GEMMA4_26B_A4B_UNSLOTH_THINKING_ON.md).

## Bigger is sometimes merely bigger

The 96 GB Mac can load models that would be absurd on a 24 GB card. This is
occasionally useful and always entertaining.

- Step-3.5-Flash-REAP-121B ran at 27.5 tokens/s at tiny context, but fell to
  3.4 tokens/s around 110K.
- MiniMax-M2.5 JANG_2L used about 68 GB and decoded at roughly 0.52 tokens/s.
  It fitted. I cannot honestly claim that waiting for it improved my life.
- Qwen3.5-122B-A10B managed about 14.9 tokens/s at tiny context and 3.2 tokens/s
  around 110K. The MoE architecture made it far more practical than its total
  parameter count suggests.

The reports are under
[Step-3.5 REAP](results/CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_STEP35_FLASH_REAP_121B.md),
[MiniMax JANG](results/MINIMAX_M2_5_JANG_MACBOOK2.md), and
[Qwen3.5-122B](results/CONTEXT_RESULTS_MACBOOK2_LLAMACPP_METAL_QWEN35_122B_A10B.md).

## DeepSeek V4 Flash and the context curve

For coding agents, the headline tokens/s number is less important than how fast
it decays as the conversation and repository context grow. A model that begins
at 100 tokens/s and collapses at 50K may be less useful than one that begins
lower and stays upright.

That is why I have also been working on
[compact REAP support in ds4](https://github.com/ljubomirj/ds4/tree/reap-compact-support).
On the M2 Max, a sub-65 GB DeepSeek-V4-Flash REAP25 GGUF remained near 10
tokens/s until roughly 784K context in my tests. It also survived a practical
benchmark that matters to me: running a local coding agent on a four-hour flight
without Internet. The laptop drew about 60 W under inference and lasted long
enough. Not better than a frontier cloud API, obviously. Still useful, and
slightly ridiculous in the pleasing way.

I wrote up that flight test and the long-context number in
[this Hacker News comment](https://news.ycombinator.com/item?id=48515485). A
related [comment on the context curve](https://news.ycombinator.com/item?id=48457071)
explains why I care about the rate of slowdown more than the best tiny-prompt
number.

The related
[Ling-2.6-Flash llama.cpp branch](https://github.com/ljubomirj/llama.cpp/tree/LJ-Ling-2.6-flash-r2)
is another attempt to make a strong hybrid MoE model work well on Metal rather
than waiting for the ideal supported stack to arrive.

## The software stack

- [llama.cpp](https://github.com/ggml-org/llama.cpp) is the common denominator:
  GGUF, Metal, Vulkan, HIP/ROCm, good instrumentation, and broad model support.
- [ds4](https://github.com/ljubomirj/ds4/tree/reap-compact-support) is the
  specialised DeepSeek V4 engine and current long-context experiment.
- [MLX](https://github.com/ml-explore/mlx) and
  [mlx-lm](https://github.com/ml-explore/mlx-lm) can be extremely fast on Apple
  Silicon, especially at short context, but model support and Metal memory
  behaviour need testing rather than faith.
- [oMLX](https://github.com/jundot/omlx) adds a practical server, model swapping,
  continuous batching, and tiered KV caching. I keep a local branch for
  long-context mitigation work.
- [LiveCodeBench](https://github.com/LiveCodeBench/LiveCodeBench) supplies the
  coding problems. The subset here is useful for A/B tests, not a claim about a
  model's universal intelligence.

## Things the tests have taught me

1. Benchmark with realistic context. Empty-context speed is a demo, not a workday.
2. Verify the active server arguments and startup log. A draft model or thinking
   flag in a shell script proves nothing if another argument array is executed.
3. Record accuracy and wall time together. A model that wins by two percentage
   points and takes three times as long has not won every use case.
4. More bits do not guarantee a better operating point. Nemotron Q8 matched the
   Q6 score while taking about 1.5 times as long.
5. Quantisation is not only about speed. Q4 and Q5 GLM were effectively tied at
   50K-55K, but Q4 bought much more context headroom.
6. Failures are results. Native Metal crashes, unsupported kernels, OOM limits,
   and a model that technically loads at 0.5 tokens/s all define the usable map.

## Where the data lives

- [`results/`](results/) contains readable summaries and comparisons.
- [`benchmark/`](benchmark/) contains older raw and scored benchmark artifacts.
- [`runs/`](runs/) contains preserved run outputs for the newer suites.
- [`scripts/`](scripts/) contains launchers and benchmark harnesses.
- [`TESTING.md`](TESTING.md) describes the original testing workflow.

The repository is a lab notebook, not a polished leaderboard. Tests were run at
different times, with different quants and engine revisions. I try to compare
like with like and call out when I cannot. Corrections and better reproductions
are welcome. I am doing this because I like local machines, open weights, and
finding out what happens when the advertised setup meets the hardware actually
sitting under my desk.
