# T-436: YOLO Mode — Auto-Compact + Auto-Resume + Autonomous Proceed

## Problem Statement

Context compaction and resume are manual operations requiring human presence at every context transition. After 150+ sessions of reliable token management, the question: can we close the loop entirely?

## D-027 Review

D-027 (2026-02-18, T-174) disabled auto-compact for these reasons:

| D-027 Concern | Still Valid? | T-436 Mitigation |
|---------------|-------------|-------------------|
| Compaction is lossy (LLM summary) | Yes — LLM summaries lose structured state | PreCompact handover captures structured state BEFORE compaction |
| Disruptive mid-session | Partially — predictable with budget monitoring | Budget gate provides early warning; pre-compact hook fires before compaction |
| T-145 deadlock (stale .budget-status) | Resolved — pre-compact.sh resets budget state (lines 37-39) | Verify reset works for auto-compact path |
| T-148 cascade (14 compactions in 13 min) | Partially — code generation still fills context fast | Budget gate blocks source edits at critical; code gen pauses before compaction |
| Wasted compaction buffer | Resolved — buffer eliminated when auto-compact off | Re-enabling would reintroduce ~33K buffer cost |

**Verdict:** 2 of 5 concerns resolved, 2 partially addressed, 1 (lossy compaction) still fundamentally true but mitigated by pre-compact handover.

## Spike 1: Hook Behavior on Auto-Compact (BLOCKED — requires testing)

**Critical question:** Do PreCompact and SessionStart:compact hooks fire when Claude Code auto-compacts?

**What we know:**
- Manual `/compact` triggers hooks — confirmed across 150+ sessions
- `autoCompactEnabled: false` currently in `~/.claude.json` — no production evidence of auto-compact hook behavior
- pre-compact.sh header says "manual /compact only (auto-compaction disabled per D-027)"

**What we need:** Enable `autoCompactEnabled: true` in a test session and verify hook firing.

**Impact:** If hooks DON'T fire on auto-compact, YOLO mode is impossible without Claude Code architecture changes. This is a hard blocker.

## Spike 2: Handover Quality Analysis

**Last 10 handovers analyzed:**
- 10/10 have filled "Where We Are" (real content, not placeholders)
- 10/10 have "Work in Progress" with task breakdowns
- 10/10 have "Suggested First Action" (actionable)
- 0/10 have unfilled [TODO] sections
- 10/10 have git state, file changes, recent commits

**Post-compact resume injects:**
- First 10 lines of "Where We Are"
- First 20 lines of "Work in Progress"
- First 5 lines of "Suggested Action"
- Active tasks summary (id, status, horizon)
- Git state, fabric topology, discovery findings

**Verdict:** Handovers are mechanically sound for human-resumed sessions. For autonomous continuation, they're insufficient — missing full task context, inception status, and human AC state.

## Spike 3: Budget Reset Verification (BLOCKED — requires testing)

L-049 deadlock was fixed in pre-compact.sh (lines 37-39: clears .budget-gate-counter and .budget-status before compaction). But this was tested only for manual `/compact` flow. Auto-compact may bypass pre-compact.sh entirely if hooks don't fire.

## Spike 4: Autonomous Continuation Design

After auto-resume, the agent would follow this decision tree:

```
1. Read handover → extract Suggested First Action
2. Check if suggested task is agent-workable:
   a. status = started-work + has unchecked Agent ACs → PROCEED
   b. status = work-completed + only Human ACs remain → SKIP (defer to human)
   c. workflow_type = inception + needs GO/NO-GO → SKIP (Tier 0 blocked)
   d. owner = human + requires human judgment → SKIP
3. If no workable task found → generate handover + exit
4. Set focus, work on task, commit, check next
5. Repeat until budget critical or no workable tasks
```

**This maps directly to CLAUDE.md § Autonomous Mode Boundaries:**
- Delegated: choose task, choose approach, run tests, commit
- NOT delegated: complete human-owned, bypass gates, Tier 0 actions

**Gap:** No structural enforcement of this decision tree. Currently relies on agent discipline (CLAUDE.md instructions). YOLO mode needs a machine-readable task picker that enforces these rules.

## Spike 5: Human-Gate Deferral Mechanism

Human-gated work (inception decisions, human AC reviews, Tier 0 approvals) should be:

1. **Queued, not skipped** — add to `.context/working/human-queue.yaml`
2. **Visible in Watchtower** — /approvals page already shows pending human actions
3. **Non-blocking** — agent moves to next workable task
4. **Resumable** — when human returns, queue provides clear action list

**Current state:** Watchtower's /approvals page already provides this. The missing piece is the agent's task-picking logic knowing to skip queued items.

## Spike 6: Risk Analysis

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Hooks don't fire on auto-compact | Critical | Unknown | Spike 1 test; fallback: keep manual compact |
| Infinite compact loop (T-148) | High | Low (budget gate exists) | Budget gate blocks source edits at critical; max compact count per session |
| Context loss (lossy compaction) | Medium | Medium | PreCompact handover captures structured state; post-compact resume injects it back |
| Work duplication (agent re-does completed work) | Medium | Low | Task status tracking; episodic memory |
| Sovereignty violation (agent acts beyond authority) | High | Low | Existing gates (task-gate, tier-0, sovereignty) remain active |
| claude-fw conflict | Medium | Medium | Auto-compact makes auto-restart redundant; need to choose one mechanism |
| Budget-gate deadlock (L-049) | High | Low | Pre-compact reset fix exists; verify for auto-compact path |

**Highest risk:** Spike 1 (hooks fire?) is existential. If hooks don't fire, no mitigation exists at the framework level.

## Spike 7: Implementation Options

### Option A: YOLO-Lite (auto-compact + auto-resume, human chooses work)
- Enable `autoCompactEnabled: true`
- PreCompact hook generates handover
- SessionStart:compact hook resumes
- Agent presents "What would you like to work on?" (same as today, just without manual /compact step)
- **Risk:** Lowest. **Value:** Removes one manual step.

### Option B: YOLO-Full (auto-compact + auto-resume + autonomous continuation)
- Everything in Option A, plus:
- Task picker logic: scan active tasks, pick next workable
- Skip human-gated work, queue it
- Continue until budget critical or no workable tasks
- **Risk:** Higher. **Value:** True autonomous operation.

### Option C: YOLO-Supervised (auto-compact + auto-resume + autonomous with guardrails)
- Everything in Option B, plus:
- Max 3 autonomous continuations per session (prevent runaway)
- Report summary to human at each transition point
- Pause if confidence is low (new subsystem, unfamiliar code)
- **Risk:** Medium. **Value:** Good balance of autonomy and safety.

**Recommendation:** Phase approach: Option A first (low risk, quick win), then Option C if A succeeds.

## Recommendation: CONDITIONAL GO

**GO for Option A (YOLO-Lite)** if Spike 1 confirms hooks fire on auto-compact. This is the minimum viable YOLO — removes the manual `/compact` step while keeping human task selection.

**DEFER Option B/C** until Option A has 20+ sessions of evidence.

**NO-GO** if Spike 1 fails (hooks don't fire) — YOLO mode is structurally impossible without Claude Code changes.

**Critical blocker:** Spike 1 must be tested before any build work. This requires enabling `autoCompactEnabled: true` in a test session and observing whether PreCompact and SessionStart:compact hooks fire.
