# Thinking / Reasoning Models Research Report

**Date:** 2026-02-24
**Purpose:** Evaluate reasoning models for local Q&A knowledge base on RTX 5060 Ti (16GB VRAM)

---

## 1. DeepSeek R1 Distillations

### Available Distills

| Model | Base | Params | Ollama Pull | Size (Q4) | Fits 16GB? |
|-------|------|--------|-------------|-----------|------------|
| R1-Distill-Qwen-7B | Qwen2.5-7B | 7B | `deepseek-r1:7b` | 4.7 GB | Yes |
| R1-Distill-Llama-8B | Llama3.1-8B | 8B | `deepseek-r1:8b` | 5.2 GB | Yes |
| R1-Distill-Qwen-14B | Qwen2.5-14B | 14B | `deepseek-r1:14b` | 9.0 GB | Yes |
| R1-Distill-Qwen-32B | Qwen2.5-32B | 32B | `deepseek-r1:32b` | 20 GB | No (needs Q3/IQ3) |

### R1-0528 Update (May 2025)

The newer R1-0528 distill to Qwen3-8B is a significant upgrade:
- **Ollama pull:** `deepseek-r1:8b` (defaults to 0528 now) or explicitly `deepseek-r1:8b-0528-qwen3-q4_K_M`
- Achieves SOTA among open-source 8B models on AIME 2024
- Surpasses Qwen3-8B by +10% on AIME
- Matches Qwen3-235B-thinking performance on some benchmarks
- Deeper reasoning: 12K -> 23K tokens per question vs original R1

### Benchmark Performance (Distills)

| Model | MATH-500 | AIME 2024 | GPQA | LiveCodeBench |
|-------|----------|-----------|------|---------------|
| R1-Distill-Qwen-7B | 92.8% | ~40% | ~45% | ~35% |
| R1-Distill-Qwen-14B | 93.9% | 69.7% | ~55% | ~45% |
| R1-Distill-Qwen-32B | 94.3% | 72.6% | ~62% | ~50% |
| R1-0528-Qwen3-8B | ~94% | ~72% | ~58% | ~48% |

### Quality Assessment

R1 distills are pure reasoning models -- they ALWAYS think. No way to disable thinking. This means:
- Every query incurs thinking latency (10-60 seconds)
- Great for complex questions, overkill for simple lookups
- The 14B sweet spot: fits comfortably in 16GB, strong reasoning

### Expected Speed on RTX 5060 Ti

- **R1-7B/8B (Q4):** ~45-55 tok/s generation
- **R1-14B (Q4):** ~28-35 tok/s generation
- **R1-32B:** Does not fit in 16GB at Q4

---

## 2. QwQ and Qwen3 (Qwen with Questions)

### QwQ (Original Reasoning Model)

| Spec | Value |
|------|-------|
| Parameters | 32B |
| Ollama pull | `qwq` |
| Size (Q4) | ~20 GB |
| Fits 16GB? | No (needs aggressive quant like IQ2_S at ~9GB) |
| GPQA | 65.2% |
| AIME | 50.0% |
| MATH-500 | 90.6% |
| LiveCodeBench | 50.0% |

QwQ is largely **superseded by Qwen3** which has built-in thinking mode toggle.

### Qwen3 Family (RECOMMENDED)

Qwen3 is unique: it supports **seamless switching between thinking and non-thinking mode**. This is the only model family that can do both natively.

| Model | Params (Active) | Ollama Pull | Size (Q4) | Fits 16GB? |
|-------|-----------------|-------------|-----------|------------|
| Qwen3-8B | 8B (8B) | `qwen3:8b` | 5.2 GB | Yes |
| Qwen3-14B | 14B (14B) | `qwen3:14b` | 9.3 GB | Yes |
| Qwen3-30B-A3B | 30B (3.3B active) | `qwen3:30b` | 19 GB | Tight (needs Q3 or IQ4) |
| Qwen3-32B | 32B (32B) | `qwen3:32b` | 20 GB | No |

**Key advantage:** The `--think` / `--think=false` toggle means ONE model serves both fast-path and reasoning-path queries. No need for two separate models.

### Qwen3 Benchmarks (Thinking Mode)

| Model | MATH-500 | AIME 2024 | GPQA | LiveCodeBench |
|-------|----------|-----------|------|---------------|
| Qwen3-8B | ~88% | ~52% | ~48% | ~45% |
| Qwen3-14B | ~92% | ~62% | ~55% | ~52% |
| Qwen3-30B-A3B | ~93% | ~65% | ~58% | ~55% |
| Qwen3-32B | ~95% | ~72% | ~62% | ~58% |

Qwen3-30B-A3B outperforms QwQ-32B despite having only 3.3B active params per token.
Qwen3-4B rivals Qwen2.5-72B-Instruct performance (remarkable efficiency).

### Expected Speed on RTX 5060 Ti

- **Qwen3-8B (Q4):** ~51 tok/s generation (benchmarked)
- **Qwen3-14B (Q4):** ~33 tok/s generation (benchmarked)
- **Qwen3-30B-A3B (Q4):** ~19 GB model, marginal fit; if loaded, MoE efficiency helps with ~25-35 tok/s active params but model loading is the bottleneck

### Non-Thinking Mode Speed

When `--think=false`, Qwen3 skips the reasoning chain entirely:
- Response starts immediately (no thinking delay)
- Same tok/s as above but no reasoning preamble
- Quality still strong for simple queries (these are excellent base models)

---

## 3. Phi-4 Reasoning (Microsoft)

### Available Models

| Model | Params | Ollama Pull | Size | Fits 16GB? |
|-------|--------|-------------|------|------------|
| Phi-4-mini-reasoning | 3.8B | `phi4-mini-reasoning` | 3.2 GB | Yes (easily) |
| Phi-4-reasoning | 14B | `phi4-reasoning` | 11 GB (Q4) | Yes |
| Phi-4-reasoning-plus | 14B | `phi4-reasoning:plus` | 11 GB (Q4) | Yes |

### Quantization Options for Phi-4-reasoning

| Variant | Ollama Pull | Size | Fits 16GB? |
|---------|-------------|------|------------|
| Q4_K_M | `phi4-reasoning:14b-q4_K_M` | 11 GB | Yes |
| Q8_0 | `phi4-reasoning:14b-q8_0` | 17 GB | Tight |
| FP16 | `phi4-reasoning:14b-fp16` | 29 GB | No |
| Plus Q4_K_M | `phi4-reasoning:14b-plus-q4_K_M` | 11 GB | Yes |
| Plus Q8_0 | `phi4-reasoning:14b-plus-q8_0` | 17 GB | Tight |

### Benchmark Performance

| Model | MATH-500 | AIME 2025 | GPQA Diamond | HumanEval |
|-------|----------|-----------|--------------|-----------|
| Phi-4-mini-reasoning (3.8B) | ~90% | ~45% | ~42% | ~75% |
| Phi-4-reasoning (14B) | ~93% | 71.4% | ~52% | ~82% |
| Phi-4-reasoning-plus (14B) | 94.6% | 82.5% | 56% | ~85% |

**Remarkable findings:**
- Phi-4-mini-reasoning (3.8B) **outperforms** DeepSeek-R1-Distill-Qwen-7B and R1-Distill-Llama-8B
- Phi-4-reasoning-plus (14B) **outperforms** DeepSeek-R1-Distill-Llama-70B (5x larger!)
- Phi-4-reasoning-plus beats the full DeepSeek-R1 (671B) on AIME 2025
- MIT licensed -- fully open for commercial use

### Expected Speed on RTX 5060 Ti

- **Phi-4-mini-reasoning (3.8B):** ~70-90 tok/s
- **Phi-4-reasoning (14B, Q4):** ~30-35 tok/s
- **Phi-4-reasoning-plus (14B, Q4):** ~30-35 tok/s

---

## 4. Thinking Mode Configuration in Ollama

### Native API Support

Ollama has built-in thinking model support since early 2025:

```python
# Python (Ollama library)
response = ollama.chat(
    model='qwen3:14b',
    messages=[{'role': 'user', 'content': 'Explain X'}],
    think=True  # Enable thinking mode
)
# response.message.thinking contains the reasoning
# response.message.content contains the final answer
```

### OpenAI-Compatible API

```json
{
    "model": "qwen3:14b",
    "messages": [...],
    "think": true
}
```

The response includes a `thinking` field in the message separate from `content`.

### CLI Control

```bash
# Enable thinking
ollama run qwen3:14b --think "complex question"

# Disable thinking (fast mode)
ollama run qwen3:14b --think=false "simple question"

# Hide thinking output (still benefits from reasoning)
ollama run qwen3:14b --think --hidethinking "question"

# Interactive toggle
/set think      # Enable mid-session
/set nothink    # Disable mid-session
```

### Open WebUI Integration

Open WebUI supports `--reasoning-parser deepseek_r1` flag for proper parsing of `<think>...</think>` tags. This renders thinking in a collapsible section.

### Model-Specific Behavior

| Model Family | Thinking Control | Think Tags |
|--------------|-----------------|------------|
| Qwen3 | `--think` / `--think=false` (toggleable) | `<think>...</think>` |
| DeepSeek R1 | Always on (cannot disable) | `<think>...</think>` |
| Phi-4-reasoning | Always on (cannot disable) | `<think>...</think>` |
| Phi-4-mini-reasoning | Always on | `<think>...</think>` |

**Critical difference:** Only Qwen3 can toggle thinking on/off. All others are always-thinking.

---

## 5. Quality vs Speed Tradeoff

### Latency Budget

For a Q&A system streaming to the user:

| Phase | Typical Duration | User Experience |
|-------|-----------------|-----------------|
| Thinking (hidden) | 5-60 seconds | "Thinking..." spinner |
| First token | After thinking completes | Response begins streaming |
| Generation | Varies by length | Streaming text |

### Is 30-60 Seconds Acceptable?

**Yes, with proper UX:**
1. Show "Thinking..." indicator with elapsed time
2. Stream the thinking process itself (optional, some users like seeing reasoning)
3. The quality improvement is dramatic -- a 14B thinking model can match a 70B non-thinking model

**User expectations by query type:**
- Simple lookup ("What is X?"): 1-3 seconds expected -> thinking is overkill
- Complex analysis ("Why does X fail when Y?"): 10-30 seconds acceptable
- Deep reasoning ("Design an approach for..."): 30-60 seconds acceptable if answer is excellent

### Streaming the Thinking Process

With Ollama's API, you can stream both thinking and answer:
```python
# Stream with thinking visible
for chunk in ollama.chat(model='qwen3:14b', messages=[...], think=True, stream=True):
    if chunk.message.thinking:
        show_thinking_indicator(chunk.message.thinking)
    if chunk.message.content:
        show_answer(chunk.message.content)
```

This transforms wait time into engagement -- users see the model "working through" the problem.

---

## 6. Hybrid Approach: Fast + Thinking

### Architecture

```
User Query
    |
    v
[Query Classifier] -- simple --> [Fast Model (no-think)] --> Stream answer
    |
    +-- complex --> [Thinking Model] --> Show "Thinking..." --> Stream answer
```

### Strategy 1: Qwen3 Single-Model Hybrid (RECOMMENDED)

Use ONE Qwen3 model with dynamic `think` toggle:
- **Simple queries:** `think=False` -> immediate response at full tok/s
- **Complex queries:** `think=True` -> reasoning chain -> better answer

**Advantages:**
- Only one model loaded in VRAM
- No model switching latency
- Simpler infrastructure
- Qwen3-14B at Q4 = 9.3 GB, leaves ~6 GB for KV cache

### Strategy 2: Two-Model Router

- **Fast model:** Qwen3-8B (5.2 GB) with `think=False`
- **Thinking model:** Phi-4-reasoning-plus (11 GB) or DeepSeek-R1-14B (9 GB)

**Problem:** Both models can't fit in 16GB simultaneously. Would need to swap models (5-15 second loading penalty).

### Strategy 3: Tiered MoE

- **Fast:** Qwen3-8B (5.2 GB, `think=False`)
- **Deep:** Qwen3-8B (same model, `think=True`)

Uses only 5.2 GB VRAM total. Toggle thinking per-query.

### Query Classification Methods

**A. Keyword/Heuristic (simplest, no ML):**
```python
COMPLEX_SIGNALS = ['why', 'how does', 'compare', 'difference between',
                   'best approach', 'debug', 'troubleshoot', 'design']
SIMPLE_SIGNALS = ['what is', 'define', 'list', 'show me', 'where is']

def classify(query):
    query_lower = query.lower()
    if any(s in query_lower for s in COMPLEX_SIGNALS):
        return 'think'
    return 'no_think'
```

**B. Length + Keyword (better):**
- Short queries (< 20 tokens) + simple keywords -> fast
- Long queries or complex keywords -> thinking
- Questions with code snippets -> thinking

**C. Embedding-based Router (best, but requires extra model):**
- Train a small classifier on (query, complexity_label) pairs
- Use sentence embeddings from a tiny model
- Research shows this approach can reduce LLM usage by 37-46%

**D. Qwen3 Native (built-in):**
Qwen3's `/think` and `/no_think` tags in the prompt let the model itself decide:
- Append `/think` for complex queries
- Append `/no_think` for simple queries
- Or let the model auto-decide (default behavior without tags)

### Recommended Hybrid Configuration

**Primary: Qwen3-14B single-model with dynamic thinking**

```yaml
model: qwen3:14b          # 9.3 GB Q4_K_M
default_think: false       # Fast by default
think_triggers:
  - query_length > 50 tokens
  - contains: [why, how, compare, debug, design, explain, difference]
  - has_code_block: true
  - follow_up_depth > 2    # Deep conversation = complex
```

This gives:
- Simple queries: ~33 tok/s, first token in <1s
- Complex queries: 10-40s thinking, then ~33 tok/s streaming
- Single model in VRAM, ~6.7 GB free for KV cache
- 128K context window

---

## 7. Model Recommendations (Ranked)

### Tier 1: Best Overall for 16GB Q&A System

| Rank | Model | Ollama Pull | Size | Why |
|------|-------|-------------|------|-----|
| 1 | **Qwen3-14B** | `qwen3:14b` | 9.3 GB | Toggleable thinking, excellent quality, good speed, leaves room for KV cache |
| 2 | **Phi-4-reasoning-plus** | `phi4-reasoning:plus` | 11 GB | Best reasoning quality at 14B, but always-on thinking adds latency to simple queries |
| 3 | **DeepSeek-R1-0528-Qwen3-8B** | `deepseek-r1:8b` | 5.2 GB | SOTA 8B reasoning, fits easily, but always-on thinking |

### Tier 2: Specialized Use Cases

| Model | Ollama Pull | Size | Use Case |
|-------|-------------|------|----------|
| Qwen3-8B | `qwen3:8b` | 5.2 GB | If 14B is too slow; still great with thinking toggle |
| Phi-4-mini-reasoning | `phi4-mini-reasoning` | 3.2 GB | Ultra-fast reasoning for constrained scenarios |
| DeepSeek-R1-14B | `deepseek-r1:14b` | 9.0 GB | Strong math/code reasoning, always-on thinking |

### Tier 3: Aspirational (Need More VRAM or Aggressive Quant)

| Model | Ollama Pull | Size | Notes |
|-------|-------------|------|-------|
| Qwen3-30B-A3B | `qwen3:30b` | 19 GB | MoE magic but doesn't fit 16GB at Q4 |
| DeepSeek-R1-32B | `deepseek-r1:32b` | 20 GB | Excellent quality, needs 24GB+ |

---

## 8. Implementation Recommendation

### Phase 1: Single Model with Dynamic Thinking

```bash
# Pull the model
ollama pull qwen3:14b

# Test thinking mode
ollama run qwen3:14b --think "Why would a React useEffect cleanup function not run?"

# Test fast mode
ollama run qwen3:14b --think=false "What is useEffect?"
```

### Phase 2: Add Query Classification

Implement a simple heuristic classifier:
- Route simple queries to `think=False`
- Route complex queries to `think=True`
- Show "Thinking..." UI indicator for thinking queries
- Optionally stream thinking tokens in a collapsible section

### Phase 3: Evaluate and Iterate

- A/B test answer quality with thinking vs without
- Track user satisfaction signals (thumbs up/down)
- Tune classification thresholds
- Consider Phi-4-reasoning-plus as a specialized deep-thinking option if Qwen3-14B reasoning quality isn't sufficient

---

## 9. RTX 5060 Ti Performance Summary

Based on actual benchmarks from localscore.ai and hardware-corner.net (2025-2026):

| Model | Quant | Model Size | Prompt Processing | Generation | Notes |
|-------|-------|-----------|-------------------|------------|-------|
| Qwen3-8B | Q4 | 5.2 GB | ~1448 tok/s | ~51 tok/s | At 16K context |
| Qwen3-14B | Q4 | 9.3 GB | ~943 tok/s | ~33 tok/s | At 16K context |
| Phi-4-reasoning (14B) | Q4 | 11 GB | ~800 tok/s est. | ~30 tok/s est. | Estimated from similar 14B |
| DeepSeek-R1-8B | Q4 | 5.2 GB | ~1400 tok/s est. | ~48 tok/s est. | Similar arch to Qwen3-8B |
| Phi-4-mini (3.8B) | Q4 | 3.2 GB | ~2000 tok/s est. | ~75 tok/s est. | Very fast |

**At 32K context (longer conversations):**
- Qwen3-8B: ~39 tok/s generation
- Qwen3-14B: ~26 tok/s generation

Context length significantly impacts speed due to KV cache pressure on 16GB VRAM.

---

## 10. Key Decisions for the Q&A System

### Decision 1: Single Model vs Dual Model
**Recommendation: Single model (Qwen3-14B)** -- The thinking toggle makes dual-model unnecessary and avoids VRAM swapping.

### Decision 2: Default Thinking Mode
**Recommendation: Off by default, on for complex queries** -- Most Q&A queries are simple lookups. Save thinking for queries that benefit from it.

### Decision 3: Thinking Visibility
**Recommendation: Stream thinking in collapsible UI section** -- Transforms latency into engagement. Users who want to see reasoning can expand; others see a brief "Thinking..." then the answer.

### Decision 4: Fallback Model
**Recommendation: Keep Qwen3-8B as fallback** -- If the 14B model is too slow for the use case, Qwen3-8B at 5.2 GB is still excellent with thinking enabled.

---

## Sources

- Ollama Thinking Docs: https://docs.ollama.com/capabilities/thinking
- Ollama DeepSeek-R1 Library: https://ollama.com/library/deepseek-r1
- Ollama Qwen3 Library: https://ollama.com/library/qwen3
- Ollama Phi4-Reasoning Library: https://ollama.com/library/phi4-reasoning
- Ollama Phi4-Mini-Reasoning Library: https://ollama.com/library/phi4-mini-reasoning
- Qwen3 Blog Post: https://qwenlm.github.io/blog/qwen3/
- DeepSeek-R1 Paper: https://arxiv.org/html/2501.12948v1
- Phi-4 Reasoning Technical Report: https://arxiv.org/abs/2504.21318
- RTX 5060 Ti LocalScore Results: https://www.localscore.ai/accelerator/860
- RTX 50 Series Best Local LLMs: https://apxml.com/posts/best-local-llms-for-every-nvidia-rtx-50-series-gpu
- Hybrid LLM Routing (ICLR 2025): https://arxiv.org/abs/2404.14618
- Reasoning Router Blog: https://huggingface.co/blog/AmirMohseni/reasoning-router
- Consumer GPU Blackwell Paper: https://arxiv.org/html/2601.09527v1
- Hardware Corner GPU Rankings: https://www.hardware-corner.net/gpu-ranking-local-llm/
