# Token Usage Analysis — Empirical Findings

**Tasks:** T-799 (usage tracking), T-800 (efficiency strategies)
**Date:** 2026-04-01
**Data source:** 6 JSONL session transcripts from `~/.claude/projects/`
**Cost model:** Subscription (flat rate) — cost is measured in **tokens consumed**, not dollars.
Token usage matters for: rate limits, context efficiency, session lifetime, and response quality.

## Key Findings

### 1. The Data Exists and Is Rich

Every assistant turn in the JSONL transcript contains a `usage` object with:

```json
{
  "input_tokens": 3,
  "cache_creation_input_tokens": 24288,
  "cache_read_input_tokens": 11313,
  "cache_creation": {
    "ephemeral_5m_input_tokens": 0,
    "ephemeral_1h_input_tokens": 24288
  },
  "output_tokens": 31,
  "service_tier": "standard"
}
```

**T-799 feasibility: CONFIRMED.** Per-turn token data with cache breakdown is available for cost tracking.

### 2. Total Token Usage Across 6 Sessions

| Session | Turns | Input (fresh) | Cache Read | Cache Create | Output | Total Tokens |
|---------|-------|---------------|------------|--------------|--------|-------------|
| 28c3b0c9 | 6 | 10 | 169K | 53K | 2K | 224K |
| 0eba9dc9 | 8,158 | 39K | 1,011M | 22M | 1.5M | 1,035M |
| 82c8632b | 109 | 2K | 6.9M | 255K | 15K | 7.2M |
| 73e2f1ed | 50 | 64 | 2.4M | 202K | 8K | 2.6M |
| 670923d6 | 36 | 5K | 1.8M | 204K | 6K | 2.0M |
| 048065d3 | 5,165 | 50K | 620M | 11M | 863K | 632M |
| **TOTAL** | **13,524** | **96K** | **1,643M** | **34M** | **2.3M** | **1,679M** |

### 3. Token Usage by Category

| Category | Tokens | % of Total |
|----------|--------|------------|
| Fresh input | 96K | 0.0% |
| Cache read | 1,643M | 97.8% |
| Cache create | 34M | 2.0% |
| Output | 2.3M | 0.1% |

**Insight:** Cache reads are 97.8% of all token traffic. This is the context window being re-read on every turn. Each turn sends the full accumulated context as cache-read tokens. The total volume — 1.64 billion tokens across 6 sessions — reflects the cumulative cost of the O(n²) attention pattern: every turn processes every prior token.

### 4. Output Is Tiny Relative to Input

Output is 0.1% of total token volume (avg 177 tokens/turn). **Context size, not output verbosity, drives token consumption.** Under a subscription, each turn's token cost is dominated by the context window being re-read — output is a rounding error.

### 5. Framework Overhead Per Session

First-turn context size across all sessions: **31K–39K tokens** (~35K average).

This is the "framework tax" — CLAUDE.md, system prompt, memory files, skills, hooks — loaded before any work begins. At $0.0525/turn (35K × $1.50/M), this is the floor cost of every turn.

### 6. Context Growth and Quadratic Cost

In the largest session (8,158 turns, $2,045):
- Average context: 125K tokens/turn
- 36% of cost came from turns with context > 150K
- 63% from turns with 50K–150K context
- Only 1% from turns with context ≤ 50K

**The quadratic tax is real but mediated by caching.** With cache reads at $1.50/M (vs $15/M fresh), the O(n²) attention cost is partially absorbed by the infrastructure. The user-facing cost scales closer to O(n) than O(n²) because of caching.

### 7. `/clear` vs Continue Simulation

Simulating `/clear` at 200K context threshold (reset to 30K framework overhead) on the 048065d3 session:
- **Actual total input tokens:** 631M
- **Simulated with /clear@200K:** ~530M
- **Reduction:** ~16% fewer tokens processed
- **Resets needed:** 14

**16% reduction is meaningful but not transformative.** The bigger lever is total turns — 8,158 turns means 8,158 context re-reads regardless. However, `/clear` also improves **context quality** — removing stale noise means better responses per token spent.

### 8. Tokens Per Turn at Different Context Levels

| Context Size | Tokens/Turn (input) | Per 100 Turns | Per 1000 Turns |
|-------------|---------------------|---------------|----------------|
| 30K | 30K | 3M | 30M |
| 50K | 50K | 5M | 50M |
| 100K | 100K | 10M | 100M |
| 150K | 150K | 15M | 150M |
| 200K | 200K | 20M | 200M |
| 500K | 500K | 50M | 500M |
| 1000K | 1,000K | 100M | 1,000M |

**Key insight:** A single turn at full 1M context consumes 33x more tokens than a turn at 30K. Over 1,000 turns, that's 1 billion vs 30 million tokens. Under a subscription with rate limits, this directly affects how many turns you can execute per minute/day.

## Directive Mapping

| Strategy | Token Impact | Antifragility | Reliability | Usability | Portability |
|----------|-------------|---------------|-------------|-----------|-------------|
| `/clear` at thresholds | -16% input tokens | Risk: lose context | Needs handover | Disrupts flow | Portable |
| Shorter sessions (fresh starts) | -10-20% | Risk: lose learning | Depends on handover | Friction | Portable |
| Context quality hygiene | Better signal/noise | **Positive**: focused context | Positive | Neutral | Portable |
| Reduce CLAUDE.md size | -35K/turn base | **Negative**: less governance | Negative | Neutral | Neutral |
| TermLink over Task agents | Isolates context | Neutral | Neutral | Neutral | Less portable |
| Output discipline (already enforced) | Marginal (0.1% of volume) | Neutral | Neutral | Neutral | Portable |
| Model selection (Haiku for sub-tasks) | Lower quality tokens | Risk: quality | Risk: quality | Neutral | Portable |

## Recommendations

### For T-799 (Token Usage Tracking)

**GO.** The data exists, is structured, and is rich enough for per-turn and per-session tracking. Implementation:
1. Parse JSONL transcripts for `assistant` entries with `usage` fields
2. Sum by category: input, cache_read, cache_create, output
3. Track per-task attribution via timestamps + focus.yaml correlation
4. Report as: tokens per task, tokens per session, project totals
5. Store in SQLite (aligns with T-699 fw stats design)
6. CLI: `fw costs` showing token usage breakdowns (not dollar amounts)

### For T-800 (Efficiency Strategies)

**Nuanced.** The findings challenge some assumptions:
1. **Output volume is negligible (0.1%)** — output discipline has zero ROI as a token strategy (still valuable for context quality)
2. **Context size is the lever** — each turn re-reads the full context window. 1,000 turns at 200K = 200M tokens. 1,000 turns at 50K = 50M tokens. 4x difference.
3. **`/clear` at thresholds saves ~16%** — but the real value is context *quality*, not just quantity. A clean 50K context outperforms a noisy 200K context.
4. **The biggest driver is total turns** — 8,158 turns consume tokens regardless of context management. Efficiency means doing the same work in fewer turns.
5. **Context quality > context quantity** — under subscription, the goal isn't "spend fewer tokens" (it's flat rate), it's "spend tokens on high-quality context that produces better output." Stale debug output, abandoned approaches, and irrelevant tool results dilute context quality.

**The reframing for subscription:** Token efficiency isn't about saving money — it's about:
- **Rate limit headroom** — staying under tokens/minute caps during intensive work
- **Session lifetime** — more useful turns before context fills up
- **Response quality** — every token of noise in context competes with signal for attention weight
- **Throughput** — smaller contexts = faster inference = more work per hour

## Dialogue Log

### Q: Does running prompts with large context cost more than small context?
**A:** Yes. Three layers: (1) per-token billing — more input tokens = more cost; (2) O(n²) attention compute — quadratic, not linear; (3) KV cache memory bandwidth. Empirically confirmed in our data: turns at 150K context cost 3.3x more than turns at 30K.

### Q: How would `/clear` help?
**A:** `/clear` resets context to zero, restarting at the cheap end of the cost curve. Simulated 16% savings on a 5,165-turn session. But context quality matters more than context size — `/clear` + selective reload of high-value context could be both cheaper AND better than continuing with polluted context full of stale debug output.

### Q: What about the framework's own overhead?
**A:** ~35K tokens loaded at session start (CLAUDE.md, memory, skills, system prompt). This is the floor cost per turn. At cache-read rates, it costs $0.0525/turn — modest individually but compounds over 8,000+ turns to ~$420 per long session.
