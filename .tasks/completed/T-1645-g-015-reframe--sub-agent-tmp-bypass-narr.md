---
id: T-1645
name: "G-015 reframe — sub-agent /tmp/ bypass: narrow T-1061 claim or open non-TermLink
  workstream"
description: >
  T-1061 was framed partly on closing G-015 (sub-agent results bypass task governance
  via /tmp/fw-agent-*.md writes). Original review-feedback artefact (item W4) explicitly
  said TermLink cannot solve this — sub-agents write to /tmp/ outside the PTY TermLink
  observes. T-1641 W02 surfaced that no follow-up workstream was opened. Decision-only
  inception, ~1 session: either (a) narrow T-1061's stated benefit by removing the
  G-015 claim and update concerns.yaml, or (b) open a non-TermLink workstream (FUSE
  / Linux namespace / hook-side) to govern sub-agent file writes. Pick one, commit.
  Source: docs/reports/T-1641-worker-02-review-feedback-mining.md item L1.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: [web/blueprints/__init__.py, web/blueprints/orchestrator.py, 
      web/templates/orchestrator.html]
related_tasks: [T-1641, T-1061, T-329]
arc_id: orchestrator-rethink
created: 2026-05-01T11:55:08Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T17:09:08Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1645: G-015 reframe — sub-agent /tmp/ bypass: narrow T-1061 claim or open non-TermLink workstream

## Problem Statement

T-1061 (orchestrator arc) was framed partly on closing **G-015** — "Sub-agent results bypass task governance — no structural linking." The original review-feedback artefact W4 (`docs/reports/T-1641-worker-02-review-feedback-mining.md`) explicitly contradicted this framing: sub-agents write their results to `/tmp/fw-agent-*.md` *outside* the PTY scope TermLink observes. **TermLink cannot see those writes**, therefore cannot govern them, therefore cannot structurally close G-015.

T-1641 W02 surfaced this as a "lost observation" — never tasked, never reconciled, but T-1061's stated G-015 benefit remains in the concerns register. This inception decides: narrow the T-1061 claim and refile G-015 as a non-TermLink workstream, or accept the gap stays open as a known tradeoff.

## Assumptions

- **A1:** TermLink genuinely cannot observe `/tmp/fw-agent-*.md` writes. Validated — TermLink scope is PTY/socket; `/tmp/` writes use direct filesystem syscalls outside any PTY. (Confirmed by W4 author.)
- **A2:** Sub-agent governance is achievable via non-TermLink mechanisms. Plausible — `fw bus post`/`fw bus manifest` already provides governed dispatch; FUSE-overlay or strace-hook is a longer path. The framework has partial mitigation today via the dispatch preamble convention (sub-agents write to `/tmp/`, return path; orchestrator integrates).
- **A3:** Keeping G-015 open while T-1061 advertises closing it is structurally misleading and erodes the gaps register's signal. Validated — the gaps register is consumed by handover and Watchtower; misframed claims compound on every read.

## Exploration Plan

Already complete via T-1641 W02 (review-feedback mining). Decision-only inception. ~1 session of dialogue + commit.

## Technical Constraints

None. This is a framing/registration decision — no code or config changes.

## Scope Fence

**IN:**
- Decide between Option A (narrow T-1061's claim, keep G-015 open) and Option B (open a non-TermLink sub-agent governance workstream).
- Update `concerns.yaml` G-015 entry to reflect the chosen framing.
- If Option B: file the companion task (FUSE / strace / framework-side bus enforcement / hook-side gate).
- If Option A: file a documentation update task to reflect the narrowed scope.

**OUT:**
- Implementing the non-TermLink workstream (separate build task on Option B).
- Re-litigating T-1061's G-015 framing in T-1061 itself (T-1061 is shipped; this fixes the *framing*, not the implementation).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if (Option A):** Human accepts the narrowing; `concerns.yaml` G-015 → `partial-mitigation` with bus protocol credited; T-1061 episodic updated; companion observation task filed.

**GO if (Option B):** Human commits 2–3 weeks of build effort to a non-TermLink sub-agent governance mechanism; FUSE/strace/hook spikes are filed.

**NO-GO if:** Human prefers to leave T-1061's G-015 claim as-is. (Strongly not recommended — gaps register integrity matters.)

**DEFER if:** A larger restructuring of the gaps register is in flight that would resolve this naturally.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO with **Option A** (narrow T-1061's G-015 claim) + a small companion observation task documenting the partial mitigation that already exists.

**Rationale:** TermLink genuinely cannot govern `/tmp/` writes — that's a categorical scope limit, not an implementation gap. Pretending T-1061 closed G-015 is structurally dishonest and erodes the gaps register. Option B (FUSE / strace / framework-side enforcement) is real engineering, ~1–2 weeks, and is not blocked by anything Option A doesn't fix; it can land later if the gap proves operationally painful. Option A costs minutes and removes the misframing immediately.

What's worth recording explicitly: the framework already has *partial* mitigation via the `fw bus post --task T-XXX` protocol (CLAUDE.md "Result Ledger" section), which gives sub-agents a structurally-governed channel that supersedes `/tmp/`. The dispatch preamble (`agents/dispatch/preamble.md`) instructs agents to use `fw bus post` instead of raw `/tmp/` writes. This is enforcement-by-convention, not by hook — but it exists. The honest framing is: G-015 has *partial mitigation* (bus protocol), not *closure* (no PreToolUse hook blocking `/tmp/fw-agent-*` writes).

**Evidence:**
- W4 ruling: TermLink scope is PTY/socket; `/tmp/` writes are out-of-scope by design — `docs/reports/T-1641-worker-02-review-feedback-mining.md` (item L1, item W4)
- T-1641 W02 confirms no follow-up workstream exists for sub-agent file-write governance
- `agents/dispatch/preamble.md` + `fw bus post` provide a partial mitigation path that the gap entry doesn't currently credit
- T-1061 episodic shows G-015 listed as benefit but never re-tested post-ship

**Concrete actions on GO Option A:**
1. Update `.context/project/concerns.yaml` G-015 entry: status `watching` → `partial-mitigation`; add `mitigations: [agents/dispatch/preamble.md, fw bus post protocol]`; add `gap_remaining: "no structural enforcement — sub-agents can still write directly to /tmp/ if they ignore the preamble"`.
2. Update T-1061 episodic (`.context/episodic/T-1061.yaml`) — change "closes G-015" → "partial mitigation for G-015 via bus protocol; does not structurally close".
3. File a small `horizon: later` observation task: "Consider PreToolUse hook on Write/Bash to redirect `/tmp/fw-agent-*.md` writes through `fw bus post`" — captures Option B as a future workstream without committing to it now.

**If Option B preferred** (less likely): file three sub-tasks — FUSE feasibility spike, strace-hook spike, framework-side `fw bus` enforcement gate. Estimate 2–3 weeks total. NOT recommended unless an operational incident proves the gap matters.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO with Option A (narrow T-1061's G-015 claim) + a small companion observation task documenting the partial mitigation that already exists.

Rationale: TermLink genuinely cannot govern `/tmp/` writes — that's a categorical scope limit, not an implementation gap. Pretending T-1061 closed G-015 is structurally dishonest and erodes the gaps register. Option B (FUSE / strace / framework-side enforcement) is real engineering, ~1–2 weeks, and is not blocked by anything Option A doesn't fix; it can land later if the gap proves operationally painful. Option A costs minutes and removes the misframing immediately.

What's worth recording explicitly: the framework already has partial mitigation via the `fw bus post --task T-XXX` protocol (CLAUDE.md "Result Ledger" section), which gives sub-agents a structurally-governed channel that supersedes `/tmp/`. The dispatch preamble (`agents/dispatch/preamble.md`) instructs agents to use `fw bus post` instead of raw `/tmp/` writes. This is enforcement-by-convention, not by hook — but it exists. The honest framing is: G-015 has partial mitigation (bus protocol), not closure (no PreToolUse hook blocking `/tmp/fw-agent-` writes).

Evidence:
- W4 ruling: TermLink scope is PTY/socket; `/tmp/` writes are out-of-scope by design — `docs/reports/T-1641-worker-02-review-feedback-mining.md` (item L1, item W4)
- T-1641 W02 confirms no follow-up workstream exists for sub-agent file-write governance
- `agents/dispatch/preamble.md` + `fw bus post` provide a partial mitigation path that the gap entry doesn't currently credit
- T-1061 episodic shows G-015 listed as benefit but never re-tested post-ship

Concrete actions on GO Option A:
1. Update `.context/project/concerns.yaml` G-015 entry: status `watching` → `partial-mitigation`; add `mitigations: [agents/dispatch/preamble.md, fw bus post protocol]`; add `gap_remaining: "no structural enforcement — sub-agents can still write directly to /tmp/ if they ignore the preamble"`.
2. Update T-1061 episodic (`.context/episodic/T-1061.yaml`) — change "closes G-015" → "partial mitigation for G-015 via bus protocol; does not structurally close".
3. File a small `horizon: later` observation task: "Consider PreToolUse hook on Write/Bash to redirect `/tmp/fw-agent-.md` writes through `fw bus post`" — captures Option B as a future workstream without committing to it now.

If Option B preferred (less likely): file three sub-tasks — FUSE feasibility spike, strace-hook spike, framework-side `fw bus` enforcement gate. Estimate 2–3 weeks total. NOT recommended unless an operational incident proves the gap matters.

**Date**: 2026-05-01T17:09:07Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-01T17:09:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Option A (narrow T-1061's G-015 claim) + a small companion observation task documenting the partial mitigation that already exists.

Rationale: TermLink genuinely cannot govern `/tmp/` writes — that's a categorical scope limit, not an implementation gap. Pretending T-1061 closed G-015 is structurally dishonest and erodes the gaps register. Option B (FUSE / strace / framework-side enforcement) is real engineering, ~1–2 weeks, and is not blocked by anything Option A doesn't fix; it can land later if the gap proves operationally painful. Option A costs minutes and removes the misframing immediately.

What's worth recording explicitly: the framework already has partial mitigation via the `fw bus post --task T-XXX` protocol (CLAUDE.md "Result Ledger" section), which gives sub-agents a structurally-governed channel that supersedes `/tmp/`. The dispatch preamble (`agents/dispatch/preamble.md`) instructs agents to use `fw bus post` instead of raw `/tmp/` writes. This is enforcement-by-convention, not by hook — but it exists. The honest framing is: G-015 has partial mitigation (bus protocol), not closure (no PreToolUse hook blocking `/tmp/fw-agent-` writes).

Evidence:
- W4 ruling: TermLink scope is PTY/socket; `/tmp/` writes are out-of-scope by design — `docs/reports/T-1641-worker-02-review-feedback-mining.md` (item L1, item W4)
- T-1641 W02 confirms no follow-up workstream exists for sub-agent file-write governance
- `agents/dispatch/preamble.md` + `fw bus post` provide a partial mitigation path that the gap entry doesn't currently credit
- T-1061 episodic shows G-015 listed as benefit but never re-tested post-ship

Concrete actions on GO Option A:
1. Update `.context/project/concerns.yaml` G-015 entry: status `watching` → `partial-mitigation`; add `mitigations: [agents/dispatch/preamble.md, fw bus post protocol]`; add `gap_remaining: "no structural enforcement — sub-agents can still write directly to /tmp/ if they ignore the preamble"`.
2. Update T-1061 episodic (`.context/episodic/T-1061.yaml`) — change "closes G-015" → "partial mitigation for G-015 via bus protocol; does not structurally close".
3. File a small `horizon: later` observation task: "Consider PreToolUse hook on Write/Bash to redirect `/tmp/fw-agent-.md` writes through `fw bus post`" — captures Option B as a future workstream without committing to it now.

If Option B preferred (less likely): file three sub-tasks — FUSE feasibility spike, strace-hook spike, framework-side `fw bus` enforcement gate. Estimate 2–3 weeks total. NOT recommended unless an operational incident proves the gap matters.

### 2026-05-01T17:09:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-58fc19a7
- **Timestamp:** 2026-06-02T14:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T17:09:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-05-01T18:58:37Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
