# T-864: Record Task Execution Stats — Research Artifact

## Question

Is it sensible and achievable to record execution statistics (timing, token cost, complexity) directly in task files?

## Findings

### What Already Exists

**Episodic summaries** (`.context/episodic/T-XXX.yaml`) already capture per-task:
- `wall_clock_minutes` — derived from git timestamps
- `commits` — count of commits matching `T-XXX`
- `files_changed`, `lines_added`, `lines_removed` — from git diff
- `duration_days` — from created to completed
- Qualitative: outcomes, challenges, decisions, successes

**Task frontmatter** already has: `created`, `last_update`, `date_finished` → duration derivable.

**Git log** reliably filters by task ID: `git log --grep="T-XXX"` works.

### What's Missing

**Per-task token cost** — not currently attributable. Sessions span multiple tasks. Costs.sh tracks session-level only. Attributing tokens to a specific task would require:
1. Scanning JSONL for `fw context focus T-XXX` boundaries
2. Summing tokens between focus-set and focus-change events
3. Problem: focus changes are imprecise — agents work on tangential things, hooks fire, sub-agents run

**Estimation approach:** JSONL transcripts can be 68MB+. Even with Python streaming, parsing per-task boundaries adds 5-30s depending on transcript size. This violates the "no expensive transcript parsing" constraint.

### Assumption Testing

| Assumption | Result |
|-----------|--------|
| A1: Per-task tokens from JSONL by focus windows | PARTIAL — focus boundaries are imprecise, parsing is expensive |
| A2: Task frontmatter can hold stats | YES — optional section, backward compatible |
| A3: Stats useful for planning | YES — episodic already enables `fw metrics predict` |
| A4: Auto-populate without expensive parsing | PARTIAL — git stats: yes (<1s). Token stats: no (5-30s) |

### Analysis

The core insight is that **episodic summaries already capture 80% of what's desired.** The gap is token cost, which is the hardest to attribute accurately.

**Option A: Enhance episodic with git stats (already done)**
- Wall clock, commits, files/lines — already computed at task completion
- No additional work needed

**Option B: Add `## Stats` section to task files**
- Duplicate of episodic data in a different location
- Marginal benefit: stats visible in task file without opening episodic
- Cost: code duplication, two places to maintain

**Option C: Add token cost estimation**
- Requires JSONL focus-window parsing
- Accuracy questionable (multi-task sessions, tangential work)
- Parsing cost: 5-30s per completion
- Better approach: session-level cost is already tracked; divide by tasks-per-session for rough estimate

## Recommendation

**NO-GO** — The problem is already substantially solved.

**Rationale:**
1. Episodic summaries already capture wall clock, commits, files changed, lines added/removed
2. `fw metrics predict` already uses this data for effort estimation
3. Per-task token attribution is inaccurate (focus boundaries are fuzzy) and expensive (large JSONL parsing)
4. Adding a `## Stats` section to task files would duplicate episodic data without new insight
5. Session-level token costs (already tracked in handovers) divided by tasks-per-session gives a reasonable approximation

**What would change this to GO:**
- A lightweight mechanism to tag JSONL entries with task IDs at the Claude Code protocol level (not available today)
- A clear use case where session-level cost approximation is insufficient

**Evidence:**
- Episodic T-043 already has: `wall_clock_minutes: 53, commits: 1, files_changed: 85, lines_added: 4043`
- Current JSONL: 68MB — parsing takes 5-30s
- `fw metrics predict --type build` already works using episodic data
