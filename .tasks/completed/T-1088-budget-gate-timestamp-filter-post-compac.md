---
id: T-1088
name: "Budget gate timestamp-filter post-compact JSONL read (real T-1087 fix)"
description: >
  Option 1 from T-1087 RCA: budget-gate.sh and checkpoint.sh both read last usage
  entry across the whole JSONL, which after /compact can include pre-compact entries
  because claude -c continues the same JSONL. Real fix: filter JSONL entries by timestamp
  during the Python scan, taking only entries with timestamp > SESSION_START_TS. post-compact-resume.sh
  should write .session-start-ts; budget-gate and checkpoint should read it. Includes
  JSONL schema verification and unit tests for the post-compact window.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-11T10:31:55Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-11T10:43:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1088: Budget gate timestamp-filter post-compact JSONL read (real T-1087 fix)

## Context

Real fix for the T-1087 regression class. JSONL schema verified: top-level `timestamp` field in ISO-8601 Z format (e.g., `2026-04-11T10:38:49.327Z`). ISO-8601 Z strings sort lexically in chronological order, so string comparison works without parsing. T-1087's Option 2 safety net is already in place; this adds the authoritative fix so the regression cycle ends.

## Acceptance Criteria

### Agent
- [x] `post-compact-resume.sh` writes `.context/working/.session-start-ts` with the current ISO-8601 Z timestamp (UTC), and its mirror in `.agentic-framework/`.
- [x] `budget-gate.sh` slow-path Python loop reads `.session-start-ts` and skips usage entries whose `timestamp` is lexically < `session_start_ts`; falls back to no-filter if the file is missing (backward compat).
- [x] `checkpoint.sh` `get_tokens_from_transcript` applies the same timestamp filter.
- [x] Both mirrored to `.agentic-framework/agents/context/`.
- [x] Unit test: construct a fake JSONL with a pre-session entry (296000 tokens) and a post-session entry (50000 tokens), set `.session-start-ts` between them, assert checkpoint reports the 50000 reading and not the 296000 reading. Added 3 tests in `tests/unit/checkpoint.bats` (filter, backward-compat, all-filtered). All 11 tests pass.
- [x] Propagated to all consumer projects via TermLink dispatch — 11/11 upgraded and verified via grep check for `session-start-ts` in each `.agentic-framework/agents/context/budget-gate.sh`.

## Verification

python3 -c "import re; f=open('agents/context/budget-gate.sh').read(); assert '.session-start-ts' in f, 'budget-gate missing session-start-ts reader'; print('budget-gate ok')"
python3 -c "f=open('agents/context/checkpoint.sh').read(); assert '.session-start-ts' in f, 'checkpoint missing session-start-ts reader'; print('checkpoint ok')"
python3 -c "f=open('agents/context/post-compact-resume.sh').read(); assert '.session-start-ts' in f, 'post-compact-resume missing session-start-ts writer'; print('post-compact-resume ok')"
python3 -c "f=open('.agentic-framework/agents/context/budget-gate.sh').read(); assert '.session-start-ts' in f; f=open('.agentic-framework/agents/context/checkpoint.sh').read(); assert '.session-start-ts' in f; f=open('.agentic-framework/agents/context/post-compact-resume.sh').read(); assert '.session-start-ts' in f; print('mirrors ok')"
bats tests/unit/checkpoint.bats > /tmp/t1088-verify.out 2>&1; grep -q "T-1088 filters pre-session-start" /tmp/t1088-verify.out && grep -q "^ok" /tmp/t1088-verify.out

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-11T10:31:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1088-budget-gate-timestamp-filter-post-compac.md
- **Context:** Initial task creation

### 2026-04-11T10:38:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-11T10:43:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-20816f25
- **Timestamp:** 2026-06-02T14:55:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
