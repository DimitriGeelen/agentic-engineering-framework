# T-844: SSD Evaluation — Simple Self-Distillation for Code Generation

**Paper:** "Embarrassingly Simple Self-Distillation Improves Code Generation" (arxiv 2604.01193)
**Authors:** Zhang, Bai, Zheng, Jaitly, Collobert, Zhang
**Date:** 2025

## Paper Summary

### What It Does
Simple Self-Distillation (SSD) improves LLM code generation by:
1. Sampling model outputs at high temperature (T=2.0) with top-k truncation (k=10)
2. Fine-tuning the same model on those samples with standard supervised learning
3. No external verifiers, teacher models, or reinforcement learning needed

### Key Results
| Model | Base pass@1 | +SSD pass@1 | Gain |
|-------|-------------|-------------|------|
| Qwen3-30B-Instruct | 42.4% | 55.3% | +12.9pp |
| Qwen3-4B-Instruct | baseline | — | +7.5pp |
| Llama-3.1-8B | baseline | — | +3.5pp |

Gains concentrate on **harder problems** (+15.3pp on hard vs +12.9pp overall).

### Core Insight: Precision-Exploration Conflict

Code generation positions split into:
- **Locks**: One correct token, long distractor tail (e.g., `if n ==` needs a specific value)
- **Forks**: Multiple valid continuations (e.g., loop vs recursion vs data structure)

Global temperature is a compromise — lowering sharpens locks but starves forks; raising diversifies forks but destabilizes locks. SSD resolves this by **contextually reshaping** distributions: suppressing tails at locks, preserving diversity at forks.

### Surprising Finding
Even with 62% gibberish training data (T=2.0, no truncation), the model still improves. **Program correctness doesn't mainly drive the gains** — support compression and distribution reshaping are sufficient.

## Framework Relevance Assessment

### Direct Applicability: LOW
- SSD requires **fine-tuning model weights** — we don't fine-tune Claude
- The technique targets model training, not inference-time behavior
- We consume Claude as a service; we don't control its training pipeline

### Conceptual Value: MEDIUM
The **precision-exploration conflict** maps to observable agentic behaviors:

1. **Lock = governance gates**: When the framework knows exactly what to do (commit, handover, task update), precise execution matters. Distractors = unnecessary exploration.
2. **Fork = design decisions**: When exploring alternatives (inception), diversity matters. Precision = premature convergence.

Our session quality metrics (T-831) could measure this:
- High edit-burst rate at locks = distractor behavior (trying multiple approaches for a known-good action)
- Low exploration at forks = premature convergence (picking the first option without alternatives)

### Inference-Time Analog: INTERESTING
The paper shows that **decoding-parameter tuning alone can't replicate SSD gains** (only 2.2pp vs 12.9pp). But the decomposition into support compression + within-support reshaping suggests:
- **Structured prompting** (our CLAUDE.md) acts as inference-time "support compression" — removing options the model shouldn't consider
- **Governance gates** act as "lock enforcement" — ensuring precision where it matters
- **Inception workflow** acts as "fork preservation" — ensuring exploration where it matters

### Potential Integration Points

1. **Temperature/sampling research for TermLink dispatch**: When spawning `claude -p` workers, we could experiment with different prompting strategies for exploration (inception) vs precision (build) tasks.

2. **Session quality metric**: Add "lock vs fork" classification to edit-burst analysis. An edit burst at a governance gate is distractor behavior; an edit burst during exploration is healthy.

3. **Prompt engineering insight**: The paper's finding that support compression matters more than correctness suggests our CLAUDE.md constraints (removing options) may be more valuable than our reward signals (AC checkboxes).

## Recommendation

**DEFER — interesting conceptual parallels but no direct actionable build.**

The precision-exploration conflict is a useful mental model for understanding agentic behavior, but SSD itself requires model fine-tuning which is outside our scope. The conceptual insights could inform future session quality analysis (T-831 follow-up) if we decide to classify agent behavior into lock/fork patterns.

**Worth revisiting if:**
- We gain access to fine-tuning (local models, open-source agents)
- The lock/fork model proves useful for analyzing session quality data
- Someone publishes an inference-time analog of SSD (prompt-level self-distillation)
