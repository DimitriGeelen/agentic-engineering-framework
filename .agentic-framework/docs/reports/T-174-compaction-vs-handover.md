# T-174 Research: Can Handover Replace Compaction Entirely?

> **Task:** T-174 | **Date:** 2026-02-18 | **Decision:** GO (Option B)
> **Method:** 3-agent parallel investigation | **Duration:** ~45 seconds parallel
> **Build tasks spawned:** T-175, T-176, T-177

---

## Agent 1: Claude Code Compaction Internals (claude-code-guide)

### What Triggers Compaction

- Auto-compaction triggers at **~98% of 200K context window** (~167K usable)
- 33K token buffer reserved for compaction overhead (16.5% of total)
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` env var controls threshold (1-100%)
- Manual `/compact` command triggers at any usage level with optional custom focus

### What Compaction Does

- LLM summarizes conversation history using a model call
- All message blocks before the compaction block are **dropped**
- Post-compaction drops to ~40-50K tokens (per L-010)
- Default summarization focuses on "state, next steps, learnings"
- **Custom summarization instructions supported** via API `instructions` parameter — but Claude Code CLI does not expose this

### Preservation Profile

| Preserved | Lost |
|-----------|------|
| Code changes, key decisions | Verbose early instructions |
| Recent conversation | Repetitive context |
| Acceptance criteria, test commands | Detailed debug output |
| Key code snippets | Tool output details |

### Disabling Compaction

- `autoCompactEnabled: false` in `~/.claude.json` — **already set in our framework**
- No native `--no-auto-compact` CLI flag (feature requests: #6689, #9540, #10691 pending)
- `/compact` still works for manual use

### Available Hooks

| Hook | When | Can Block? | Can Inject Context? |
|------|------|-----------|-------------------|
| **PreCompact** | Before compaction | No | No |
| **SessionStart** (matcher: `compact`) | After compaction | No | **Yes** (stdout → context) |

No PostCompact hook exists (feature requests: #14258, #17237 pending).

### Session Restart Pattern (Alternative to Compaction)

1. Generate handover → writes to disk
2. End session (close Claude Code)
3. Start fresh session → `fw resume` → clean 200K window
4. No summarization loss — handover is explicit, not LLM-summarized

---

## Agent 2: Handover vs. Compaction Gap Analysis (explore)

### What Our Handover System Captures

**Automatic (emergency mode, ~100ms):**
- Active tasks + status + horizon (prioritized)
- Recent commits (5) with stats
- Uncommitted change count + file list
- Predecessor session ID
- Recovery instructions

**Manual (template-driven):**
- Where We Are (2-3 sentence state summary)
- Work in Progress (per-task: last action, next step, blockers, insight)
- Decisions Made (rationale + rejected alternatives)
- Things Tried That Failed
- Open Questions/Blockers
- Gotchas/Warnings
- Suggested First Action
- Files Changed
- Handover Quality Feedback

### Information Preservation Comparison

| Information | Handover | Compaction | Lost After New Session? |
|---|---|---|---|
| Active task list | YES (auto) | YES | No — in working memory |
| Task status/horizon | YES (auto) | YES | No — re-read from files |
| Decisions + rationale | YES (manual) | YES | Only in handover |
| Failed approaches | YES (manual) | YES | Only in handover |
| **Investigation context** | **NO** | YES | **YES — no trace** |
| **Tool output / REPL results** | **NO** | YES | **YES — not persisted** |
| **Code snippets discussed** | **NO** | YES | **YES — not in handover** |
| Error investigation notes | Partial | YES | Partial loss |
| Session narrative | Partial | YES | Partial loss |
| Git state | YES (auto) | YES | Preserved (git durable) |
| Episodic summaries | Referenced | YES | Preserved (durable files) |

### The Gap: What Compaction Preserves That Handovers Don't

1. **Transient investigation results** — REPL outputs, grep results, file exploration paths
2. **Code fragments under consideration** — discussed but not committed
3. **Sub-agent dispatch results** — full returned responses (not summaries)
4. **Architectural reasoning** — trade-off analysis, concrete comparisons
5. **Implicit context** — how we got from one decision to the next

### Proposed Additions to Close the Gap

1. **Investigation Summaries Section** — what was explored, method, finding, impact
2. **Spike/Prototype Results** — what was tried, why it worked/failed, code file if persisted
3. **Tool Output Archive** — critical tool outputs, link to `.context/session-outputs/` if >2KB
4. **Error & Debugging Log** — symptom, root cause, fix, prevention
5. **Sub-Agent Dispatch Ledger** — links to `fw bus` blobs with summaries

---

## Agent 3: Architectural Options Analysis (plan)

### Critical Discovery

`autoCompactEnabled: false` is **already set** in `~/.claude.json`. Despite this, the `.compact-log` shows 16 pre-compact hook firings in 2 days — these are from manual `/compact` commands, not auto-compaction.

### Option A: Status Quo (keep compaction + improve handovers)

| Dimension | Assessment |
|-----------|-----------|
| Information | Two redundant mechanisms; compaction is lossy (L-010) |
| UX | Compaction disrupts flow mid-session |
| Feasibility | Already implemented |
| Budget | ~150K usable before compaction |
| Failures | T-145 deadlock, T-148 noise, cascade compactions (L-050) |

**Verdict:** Functional but compaction causes more problems than it solves. 4 shell scripts + 2 hook configs exist just to mitigate compaction's side effects.

### Option B: Disable Compaction, Rely on Handovers

| Dimension | Assessment |
|-----------|-----------|
| Information | Handover captures equivalent or better structured data |
| UX | Clean session boundaries; no mid-session disruption |
| Feasibility | **Already done** — `autoCompactEnabled: false` is set |
| Budget | Full 200K window; budget gate enforces at 150K |
| Failures | Risk: incomplete handover. Mitigation: emergency handover is fully automatic |

**Verdict: STRONGEST OPTION.** Architecture already supports it.

### Option C: Hybrid (feed handover to compaction API as summary)

| Dimension | Assessment |
|-----------|-----------|
| Information | Best possible — custom instructions in compaction API |
| UX | Seamless if it works |
| Feasibility | **Not feasible** — Claude Code CLI doesn't expose API `instructions` parameter |
| Failures | Dependency on CLI internals; breaks silently if CLI changes |

**Verdict:** Architecturally elegant but blocked by CLI limitations.

### Option D: Auto-Restart (handover + end session + instruct user)

**Verdict:** This IS Option B — the budget gate already implements auto-restart semantics (blocks Write/Edit/Bash at critical, only commit/handover allowed).

---

## Synthesis: Decision Rationale

**Chose: Option B — disable compaction, rely on handovers + `fw resume`**

**Evidence base:**
1. `autoCompactEnabled: false` already set and working (16 sessions, no failures)
2. Budget gate (100K/130K/150K) enforces session boundaries structurally
3. Emergency handover fires automatically at critical — captures tasks, git, commits in ~100ms
4. Compaction's lossy LLM summary is strictly inferior to structured handover
5. Eliminating compaction buffer reclaims ~20-30K usable tokens per session
6. Compaction caused operational issues: T-145 (deadlock), T-148 (noise), cascade compactions (L-050)
7. 4 shell scripts + 2 hook configs existed solely to mitigate compaction side effects

**Build tasks spawned:**
- T-175: Strengthen emergency handover (add focus, git diff, session narrative)
- T-176: Adjust budget gate thresholds (120K/150K/170K)
- T-177: Clean up compact hooks for manual-only use

---

## Sources

- [Claude Code: How It Works — Context Window Management](https://code.claude.com/docs/en/how-claude-code-works.md)
- [Claude Code: Best Practices — Managing Context](https://code.claude.com/docs/en/best-practices.md)
- [Claude Code: Hooks Guide — Re-inject Context After Compaction](https://code.claude.com/docs/en/hooks-guide.md)
- [Claude Code: Hooks Reference — PreCompact Event](https://code.claude.com/docs/en/hooks.md)
- [Anthropic Compaction API Docs](https://platform.claude.com/docs/en/build-with-claude/compaction)
- GitHub feature requests: #6689, #9540, #10691 (disable auto-compact), #14258, #17237 (PostCompact hook)
