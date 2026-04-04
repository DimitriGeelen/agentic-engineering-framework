# T-830: Session Length Optimization — Research Artifact

## Problem Statement

Should we use `/clear` proactively (not just at budget critical) to improve session quality and reduce costs? Three dimensions to evaluate:

1. **Cost:** Does clearing reduce cache read tokens?
2. **Quality:** Does fresh context improve agent output quality?
3. **Measurement:** Can we devise tests to track these over time?

## Dimension 1: Token Usage Analysis

### Real project data
- 15,238 total turns across 10 sessions (JSONL transcripts)
- 1.82B total tokens consumed (cache read dominates: 97-98% in long sessions)
- Two mega-sessions: 8,155 turns (1.0B tokens) and 6,760 turns (823M tokens)

### Model results

Context fills to 200K ceiling within ~8 turns. After that, every turn reads the full window.

| Strategy | Tokens/1000 turns | vs Continuous |
|----------|-------------------|---------------|
| Continuous (no clear) | 200.0M | baseline |
| Clear every 50 turns | 214.9M | +7.5% MORE |
| Clear every 100 turns | 207.4M | +3.7% MORE |
| Clear every 200 turns | 203.7M | +1.9% MORE |

### Per-clear token budget
- Tokens saved (ramp-up, 9 turns at lower context): **855K**
- Tokens spent (overhead: handover + resume, 8 turns at full context): **1.6M**
- **Net per /clear: -745K tokens** (costs more, not less)

### Why tokens go UP
- After /clear, context starts at ~25K (handover injection)
- Grows to 200K ceiling in just ~8 turns (very brief savings window)
- The 8 overhead turns (handover, resume, reorientation) each read 200K
- Ramp-up savings (855K) < overhead cost (1.6M)

**Conclusion:** For raw token reduction, /clear is counterproductive. But token cost is NOT the only currency — quality matters more.

### The quality-token tradeoff
Token cost of /clear is ~745K per clear. But if stale context causes even ONE:
- Failed approach (20 wasted turns) = **4.0M tokens wasted**
- Human correction loop (10 turns) = **2.0M tokens wasted**
- Instruction drift error (5 turns to fix) = **1.0M tokens wasted**

If /clear prevents 1 such incident per 100 turns, it **saves ~2.4M net tokens** despite the 745K overhead.

## Dimension 2: Quality Analysis

This is the more important dimension. Quality degradation in long sessions is real but hard to measure.

### Hypothesized quality benefits of /clear

1. **Context pollution reduction** — Long sessions accumulate stale tool results, superseded code versions, abandoned approaches. Fresh context has only the curated handover.

2. **Instruction adherence** — CLAUDE.md and framework rules may drift out of attention as context fills with conversation. Fresh sessions re-inject them prominently.

3. **Reduced hallucination risk** — With 200K of context, the model may confuse earlier state with current state (e.g., referencing a file version from 500 turns ago).

4. **Decision freshness** — Agent in a long session may anchor on early decisions. Fresh context forces re-evaluation.

5. **Reduced repetition loops** — Long sessions sometimes enter repetitive patterns (re-reading same files, re-attempting same approaches). Fresh context breaks the cycle.

### Hypothesized quality COSTS of /clear

1. **Working memory loss** — Even with handover, nuanced understanding of "why we tried X and it failed" is lost.

2. **Momentum interruption** — Complex multi-step tasks lose their flow. The agent needs several turns to rebuild mental model.

3. **Handover fidelity** — Handovers capture WHAT was done, not always WHY. Subtle context about rejected approaches, half-formed ideas, or unstated constraints is lost.

4. **Framework overhead** — Each resume involves reading handover, syncing working memory, checking tasks — 5-8 turns of non-productive work.

## Dimension 3: Measurement Framework

### Proposed metrics (trackable over time)

#### A. Efficiency metrics (per session)
- **Commits per turn** — Higher = more productive. Track across sessions.
- **Tasks completed per 100 turns** — Normalized productivity.
- **Turns to first commit** — How quickly does productive work start? (Lower = better session start)
- **Error/retry rate** — Count of failed tool calls or repeated edits to same file. Higher = quality degradation.

#### B. Quality signals (per session)
- **AC pass rate on first attempt** — How often do verification gates pass on first try?
- **Human correction count** — How often does the human redirect or correct the agent?
- **Loop detection triggers** — Already tracked by the loop detector hook.

#### C. Context health indicators
- **Context utilization at commit** — What % of context is used when commits happen? (Earlier commits at lower context = good)
- **Handover fidelity score** — After /clear, how many turns until the agent demonstrates correct state understanding?
- **Stale reference count** — How often does the agent reference something from >200 turns ago?

### Proposed test design

**A/B comparison over 10 sessions:**

Group A (Control): Normal operation — run until budget gate fires at 190K
Group B (Treatment): Proactive /clear at 100K tokens (~50% of window)

**Measured per session:**
1. Commits count
2. Tasks completed
3. Turns total
4. Error/retry rate (grep for "FAIL" in tool results)
5. Human corrections (count user messages that redirect)
6. Time to first productive commit

**Implementation:**
- Add `session_clear_policy: "natural" | "proactive-100K"` to handover frontmatter
- Add `commits_count`, `error_count`, `first_commit_turn` to handover frontmatter
- Build a `/efficiency` Watchtower page that charts these over time
- Compare Group A vs Group B after 10 sessions each

### Quick wins (no test needed)
- Already tracked: token usage per session, turns, loop detector triggers
- Easy to add: commits per session, first commit turn number
- Harder: human correction count (requires parsing conversation)

## Recommendation

**GO with phased approach:**

1. **Phase 1 (build):** Add efficiency metrics to handover frontmatter (commits, errors, first commit turn). Display on /timeline. This is foundation for any measurement.

2. **Phase 2 (experiment):** Run 10 sessions with proactive /clear at 100K and 10 without. Compare metrics.

3. **Phase 3 (decide):** If quality metrics improve by >10% with proactive /clear, make it default despite the ~4% cost increase. Quality > cost.

**Key insight:** The cost analysis shows /clear INCREASES spend. But if it improves quality (fewer errors, fewer human corrections, better AC pass rates), the cost increase is trivially justified — one avoided bug fix pays for dozens of /clear cycles.

## Assumptions
1. Quality degradation in long sessions is real (anecdotal, not yet measured)
2. Handover fidelity is sufficient to recover within 8 turns
3. Efficiency metrics are meaningful proxies for quality
4. 10 sessions per group is sufficient for signal
