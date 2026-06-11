---
id: T-1480
name: "T-1480: fw doctor surfaces duplicate framework hooks (extends T-1479 to read-only
  diag)"
description: >
  T-1480: fw doctor surfaces duplicate framework hooks (extends T-1479 to read-only
  diag)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-25T21:32:39Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T21:35:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1480: T-1480: fw doctor surfaces duplicate framework hooks (extends T-1479 to read-only diag)

## Context

T-1479 added duplicate-hook detection during `fw upgrade`. Users may not run upgrade often enough to see the warning. `fw doctor` is read-only diagnostics — natural place to surface the same check on every health-check pass. Reuse the same `(event, hook_name)` tuple intersection from T-1479's python helper.

## Acceptance Criteria

### Agent
- [x] `bin/fw doctor` Check 6 (Claude Code hooks) emits a `WARN` when overlap exists between `$HOME/.claude/settings.json` and `$PROJECT_ROOT/.claude/settings.json`
- [x] Warning lists the duplicate `(event:hook_name)` pairs
- [x] When no overlap, no extra line is emitted (signal-to-noise — gated on non-empty `$dup_pairs`)
- [x] When `~/.claude/settings.json` doesn't exist or is malformed, the check degrades gracefully (`if [ -f ... ]` + python try/except)
- [x] `bash -n bin/fw` passes
- [x] `bin/fw doctor` runs end-to-end without erroring (verified — 16-pair warning printed)
- [x] bats test `tests/unit/doctor_duplicate_hook_detection.bats` passes (6/6)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

grep -q "Duplicate framework hook" bin/fw
grep -q '\$HOME/.claude/settings.json' bin/fw
bash -n bin/fw
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/doctor_duplicate_hook_detection.bats

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

### 2026-04-25T21:32:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1480-t-1480-fw-doctor-surfaces-duplicate-fram.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fcd4f19a
- **Timestamp:** 2026-06-02T14:57:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `bin/fw doctor` Check 6 (Claude Code hooks) emits a `WARN` when overlap exists between `$HOME/.claude/settings.json` and `$PROJECT_ROOT/.claude/settings.json`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=PROJECT_ROOT/.claude/settings.json in: `bin/fw doctor` Check 6 (Claude Code hooks) emits a `WARN` when overlap exists between `$HOME/.claude/settings.json` and `$PROJECT_ROOT/.claude/settin`

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/doctor_duplicate_hook_detection.bats`
### 2026-04-25T21:35:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
