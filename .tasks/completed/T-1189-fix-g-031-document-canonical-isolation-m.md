---
id: T-1189
name: "Fix G-031: document canonical isolation model — vendored dir + shim patterns,
  doctor detection for legacy patterns"
description: >
  Fix G-031: document canonical isolation model — vendored dir + shim patterns, doctor
  detection for legacy patterns

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T21:46:16Z
last_update: '2026-08-16T22:24:25Z'
date_finished: 2026-04-12T21:48:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1189: Fix G-031: document canonical isolation model — vendored dir + shim patterns, doctor detection for legacy patterns

## Context

G-031: Five isolation patterns coexist undocumented (T-1100 inception, GO). Fix: add fw doctor checks for legacy/problematic patterns + document the canonical model in FRAMEWORK.md. Inception: T-1100.

## Acceptance Criteria

### Agent
- [x] `fw doctor` warns on nested `.agentic-framework` inside vendored dir
- [x] `fw doctor` warns on oversized global install (>100MB at `~/.agentic-framework`)
- [x] FRAMEWORK.md documents canonical isolation model (vendored + shim)
- [x] G-031 marked resolved in concerns.yaml

## Verification

bash -c 'bin/fw doctor 2>&1 | grep -q "OK\|WARN\|checks passed"'
grep -q "Isolation Model" FRAMEWORK.md

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

### 2026-04-12T21:46:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1189-fix-g-031-document-canonical-isolation-m.md
- **Context:** Initial task creation

### 2026-04-12T21:48:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1fbfa3be
- **Timestamp:** 2026-06-02T14:55:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash -c 'bin/fw doctor 2>&1 | grep -q "OK\|WARN\|checks passed"'`
