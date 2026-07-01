# T-1687 Grilling Session — Telemetry & Truncation Analysis

**Date:** 2026-07-01  
**Context:** Applying grill-with-docs skill to escalation-triage orchestrator plan

## Question 1: Telemetry for False-Positive Rate & Costs

### What's currently tracked

From `escalation-drift-LATEST-v0.5.yaml`:
```yaml
dispatched: 0
skipped_idempotent: 5
errors: 0
```

Per-candidate fields:
- `verdict` (real_symptom_fix | false_positive | defer | ERROR)
- `latency_s` (LLM call time)
- `dispatch_id` (links to .context/dispatches.jsonl)

### What's NOT tracked

**No aggregate FP rate metrics:**
- No `false_positive_count` or `false_positive_rate` field in the output
- To calculate FP rate, you must manually count `verdict: false_positive` across the `candidates:` list
- The 64.7% FP rate from T-1727 report was a ONE-TIME manual analysis, not continuous telemetry

**No cost tracking:**
- No token counts (input or output)
- No cost estimates (even though `cost_cap_usd: 0.0` is in the workflow)
- No aggregation of LLM budget spent
- `latency_s` is tracked but doesn't translate to cost

**No trending over time:**
- Each run overwrites `LATEST-v0.5.yaml`
- Historical FP rates not preserved
- Can't detect if heuristic is getting worse/better

### Verdict: **NO** — FP rate telemetry is not wired in

**What should exist:**
1. Aggregate counts in the YAML output:
   ```yaml
   verdict_breakdown:
     real_symptom_fix: 50
     false_positive: 110
     defer: 0
   false_positive_rate: 0.647
   ```

2. Token/cost tracking per dispatch (already captured in dispatches.jsonl, just needs aggregation):
   ```yaml
   total_tokens: 450000
   avg_tokens_per_candidate: 2647
   estimated_cost_usd: 0.00  # local model
   ```

3. Time-series append instead of overwrite:
   - Keep `escalation-drift-LATEST-v0.5.yaml` for current state
   - Append to `escalation-drift-history.jsonl` for trending

## Question 2: Why Truncate at 6000 Characters?

### Current implementation

```python
CANDIDATE_BODY_TRUNCATE = 6000  # chars; keeps prompts under ~8K tokens
```

From the code comment: **"keeps prompts under ~8K tokens"**

### Why 8K tokens?

The workflow uses `model: claude-3-5-sonnet-hermes3` via local ollama-loop (`worker_kind: ollama-loop`). The comment assumes:
- ~4 chars/token ratio → 6000 chars ≈ 1500 tokens for body
- Rest of prompt template (instructions, calibration examples, frontmatter) ≈ 6500 tokens
- Total budget ≈ 8K tokens

**But this is sized for the LOCAL 7-8B model**, not Claude 3.5 Sonnet!

Claude 3.5 Sonnet supports **200K context window**. The 8K cap is an artifact of:
1. Original design targeting small local models (hermes3:8b)
2. L-355 ceiling: "7-8B local models cap at 76-79% accuracy"
3. `cost_cap_usd: 0.0` enforces local-only (no cloud fallback)

### Why is truncation a problem?

**Example failure scenario:**
```markdown
# Task body structure (typical)
[frontmatter]                    # 0-500 chars
## Context                       # 500-1000 chars
## Acceptance Criteria           # 1000-3000 chars
## Verification                  # 3000-4000 chars
## Decisions                     # 4000-5500 chars
## RCA                           # 6500-7500 chars ← TRUNCATED!
## Updates                       # 7500-9000 chars
```

If the `## RCA` section starts at char 6500, **the classifier never sees it** because truncation cuts at 6000. The LLM then correctly classifies as `real_symptom_fix` (no RCA visible) even though an RCA exists deeper in the file.

### Why do we truncate? — Three hypotheses

**H1: Token budget (outdated)**  
The 8K budget made sense for local 7-8B models. But the workflow is configured to call Claude 3.5 Sonnet (`claude-3-5-sonnet-hermes3`), which has 200K context. The truncation is cargo-culted from an earlier iteration.

**H2: Cost containment (misapplied)**  
Truncation saves tokens → saves cost. But `cost_cap_usd: 0.0` already caps spend at zero by forcing local models. If we're using local ollama anyway, why truncate?

**H3: Latency optimization**  
Shorter prompts = faster inference on local GPU. But `latency_s` data shows 2-5 seconds per call — not a bottleneck worth optimizing at the cost of accuracy.

### Recommendation: **Remove the truncation**

**Evidence:**
1. Current model supports 200K context (25× the 8K budget)
2. Average task body is ~3-4K chars (well under any reasonable cap)
3. The FP rate is already 64.7% — losing evidence to truncation makes it worse
4. Truncation saves maybe 1-2 seconds per call but costs classification accuracy

**Proposed change:**
```python
# BEFORE
CANDIDATE_BODY_TRUNCATE = 6000  # chars; keeps prompts under ~8K tokens

# AFTER
CANDIDATE_BODY_TRUNCATE = 50000  # chars; Claude 3.5 Sonnet supports 200K tokens
# Only truncate pathologically large tasks (>50K chars = ~12.5K tokens)
```

Or better yet: **don't truncate at all** — just pass the full task body. Let the model's context window handle it.

## Cross-cutting insight: Spend optimization strategy

User's framing is correct:
> "reducing inflow should focus on saving by focussing on selecting the right ones and then spend/invest to get good outcomes"

**Current state (wasteful):**
- Loose heuristic → 170 candidates/month
- 64.7% are FP → ~110 wasted LLM calls
- Truncation → classification accuracy degraded
- No telemetry → can't measure improvement

**Optimized state:**
1. **Tighten the heuristic** (reduce inflow):
   - Check for learning references (L-NNN, PL-NNN) — if present, likely not symptom-fix
   - Check git diff: if task touched no code files, likely not a fix
   - Check for out-of-line RCA artifacts (`docs/reports/T-XXX-rca-*.md`)
   - Target: 50% reduction in candidates (170 → 85/month)

2. **Remove truncation** (improve accuracy on remaining candidates):
   - Full task body → LLM sees all evidence
   - RCA sections at any depth are visible
   - Better classification → fewer FPs slip through

3. **Wire telemetry** (measure results):
   - Track FP rate per run
   - Trend over time → validate heuristic improvements
   - Token/cost tracking → quantify savings

4. **Invest in better outcomes** (for confirmed symptom-fixes):
   - Once FP rate drops to ~20%, invest in automated remediation workflows
   - E.g., auto-file RCA-improvement tasks for confirmed symptom-fixes
   - Or: notify task author via ntfy with RCA template

## Next grilling questions

1. **Why is there no feedback loop from verdicts to heuristic tuning?** Worker 3 is still investigating, but I suspect verdicts are write-only (no read-back to improve H1/H2/H3 rules).

2. **What's the actual intended workflow for handling `real_symptom_fix` verdicts?** The scan produces a queue, but what happens next? Manual review? Auto-escalation? This seems underspecified.

3. **Why is the workflow `worker_kind: ollama-loop` but the scanner does its own HTTP POST?** The resolver builds the envelope but the scanner bypasses the worker-kind abstraction. This creates coupling — any orchestrator improvements to ollama-loop won't apply here.
