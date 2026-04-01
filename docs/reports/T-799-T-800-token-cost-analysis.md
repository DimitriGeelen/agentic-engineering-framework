# Token Cost Analysis — Empirical Findings

**Tasks:** T-799 (cost tracking), T-800 (efficiency strategies)
**Date:** 2026-04-01
**Data source:** 6 JSONL session transcripts from `~/.claude/projects/`

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

### 2. Total Costs Across 6 Sessions

| Session | Turns | Cost |
|---------|-------|------|
| 28c3b0c9 | 6 | $1.40 |
| 0eba9dc9 | 8,158 | $2,045.19 |
| 82c8632b | 109 | $16.30 |
| 73e2f1ed | 50 | $7.98 |
| 670923d6 | 36 | $7.04 |
| 048065d3 | 5,165 | $1,202.27 |
| **TOTAL** | **13,524** | **$3,280.18** |

**Pricing used:** Opus 4 — $15/M input, $1.50/M cache read, $18.75/M cache create, $75/M output.

### 3. Cost Breakdown by Category

| Category | Cost | % of Total |
|----------|------|------------|
| Fresh input | $1.43 | 0.0% |
| Cache read | $2,464.31 | 75.1% |
| Cache create | $638.56 | 19.5% |
| Output | $175.88 | 5.4% |

**Insight:** Cache reads dominate at 75% of cost. Even at a 90% discount vs fresh input, the sheer volume (1.64 billion cache-read tokens) makes it the biggest line item. Without caching, input would have cost $24,643 — caching saved $22,179.

### 4. Output Is Cheap (Relatively)

Output tokens are 50x more expensive per token than cache reads, but output is only 5.4% of total cost because output volume is small (avg 177 tokens/turn). **Context size, not output verbosity, is the primary cost lever.**

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

Simulating `/clear` at 200K context threshold (reset to 30K framework overhead):
- **Actual cost:** $1,202.91
- **Simulated with /clear@200K:** $1,007.93
- **Savings:** $194.98 (16%)
- **Resets needed:** 14

**16% savings is meaningful but not transformative.** The bigger lever is the total number of turns — sessions with 5,000+ turns are expensive regardless of context management.

### 8. Cost Per Turn at Different Context Levels

| Context | Cost/Turn | Per 100 Turns | Per 1000 Turns |
|---------|-----------|---------------|----------------|
| 30K | $0.045 | $4.50 | $45 |
| 50K | $0.075 | $7.50 | $75 |
| 100K | $0.150 | $15.00 | $150 |
| 150K | $0.225 | $22.50 | $225 |
| 200K | $0.300 | $30.00 | $300 |
| 500K | $0.750 | $75.00 | $750 |
| 1000K | $1.500 | $150.00 | $1,500 |

**Key insight:** With the 1M context window, a single turn at full context costs $1.50 — the same as 33 turns at 30K context. Context bloat is a 33x cost multiplier.

## Directive Mapping

| Strategy | Cost Impact | Antifragility | Reliability | Usability | Portability |
|----------|-------------|---------------|-------------|-----------|-------------|
| Prompt caching (already active) | -90% on repeats | Neutral | Neutral | Neutral | Provider-specific |
| `/clear` at thresholds | -16% | Risk: lose context | Needs handover | Disrupts flow | Portable |
| Shorter sessions (fresh starts) | -10-20% | Risk: lose learning | Depends on handover | Friction | Portable |
| Reduce CLAUDE.md size | -$0.02/turn | **Negative**: less governance | Negative | Neutral | Neutral |
| TermLink over Task agents | Variable | Neutral | Neutral | Neutral | Less portable |
| Output discipline (already enforced) | -5% of 5% = marginal | Neutral | Neutral | Neutral | Portable |
| Model selection (Haiku for sub-tasks) | -80% per sub-task | Risk: quality | Risk: quality | Neutral | Portable |

## Recommendations

### For T-799 (Cost Tracking)

**GO.** The data exists, is structured, and is rich enough for per-turn cost calculation. Implementation is straightforward:
1. Parse JSONL transcripts for `assistant` entries with `usage` fields
2. Sum by category (fresh, cache_read, cache_create, output) x pricing
3. Attribute to tasks via timestamps + focus.yaml correlation
4. Store in SQLite (aligns with T-699 fw stats design)

### For T-800 (Efficiency Strategies)

**Nuanced.** The findings challenge some assumptions:
1. **Prompt caching is already active and saving 90%** — there's no "enable caching" optimization to capture
2. **Output cost is negligible (5%)** — output discipline has low ROI as a cost strategy (still valuable for context management)
3. **Context size is the lever** — but reducing it conflicts with Antifragility (rich context prevents failures)
4. **`/clear` at thresholds saves ~16%** — meaningful, but the real question is whether context quality degrades enough to justify the disruption
5. **The biggest cost driver is session length (total turns)** — 8,158 turns x $0.25/turn = $2,045. Fewer turns = less cost, but that means doing less work

**The honest answer:** The framework is already well-optimized by Anthropic's caching infrastructure. The remaining optimizations either conflict with governance quality or save modest amounts. The highest-ROI action is **cost visibility** (T-799), not cost reduction (T-800).

## Dialogue Log

### Q: Does running prompts with large context cost more than small context?
**A:** Yes. Three layers: (1) per-token billing — more input tokens = more cost; (2) O(n²) attention compute — quadratic, not linear; (3) KV cache memory bandwidth. Empirically confirmed in our data: turns at 150K context cost 3.3x more than turns at 30K.

### Q: How would `/clear` help?
**A:** `/clear` resets context to zero, restarting at the cheap end of the cost curve. Simulated 16% savings on a 5,165-turn session. But context quality matters more than context size — `/clear` + selective reload of high-value context could be both cheaper AND better than continuing with polluted context full of stale debug output.

### Q: What about the framework's own overhead?
**A:** ~35K tokens loaded at session start (CLAUDE.md, memory, skills, system prompt). This is the floor cost per turn. At cache-read rates, it costs $0.0525/turn — modest individually but compounds over 8,000+ turns to ~$420 per long session.
