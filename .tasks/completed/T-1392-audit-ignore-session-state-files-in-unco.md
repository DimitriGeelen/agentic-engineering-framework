---
id: T-1392
name: "Audit: ignore session-state files in uncommitted-changes check"
description: >
  Audit: ignore session-state files in uncommitted-changes check

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004]
related_tasks: []
created: 2026-04-23T11:01:51Z
last_update: 2026-04-23T11:16:09Z
date_finished: 2026-04-23T11:16:09Z
---

# T-1392: Audit: ignore session-state files in uncommitted-changes check

## Context

Audit step "Check for uncommitted changes" (audit.sh:817-824) calls `git status --porcelain` blindly and warns whenever ANY file has uncommitted modifications. Cron-driven session-state files (watchtower.log, .session-metrics.yaml, audits/*.yaml, monitors/*.{yaml,jsonl}, etc.) churn constantly and trigger the warning during normal operation. Audit trend report shows "Uncommitted changes present" recurring 39 times — pure noise that crowds out real signal.

## Acceptance Criteria

### Agent
- [x] `audit.sh` filters known session-state paths before counting uncommitted changes
- [x] Filter set covers: `.context/working/{watchtower.*,session.yaml,focus.yaml,.session-metrics.yaml,.tool-counter,.edit-counter,.budget-status,.gate-bypass-log.yaml,.approval-notified}`, `.context/audits/`, `.context/monitors/`, `.context/approvals/{pending,resolved}-*.yaml`, `.context/project/metrics-history.yaml`
- [x] Clean-with-only-noise → audit reports `PASS` with informational note ("N session-state files modified") not WARN
- [x] Real source/code dirty → still WARN, evidence shows real-vs-ignored counts (no regression on the actual signal)
- [x] Bats unit test asserts both branches (clean-with-noise = pass; dirty-with-real-changes = warn) — 3 tests pass

## Recommendation

**Recommendation:** Agent ACs complete — ready for human merge approval
**Rationale:** Trend audit was reporting "Uncommitted changes" 39 consecutive times despite changes being legitimate session-state churn. Fix filters that noise so the WARN actually means something. Live verification on this repo: 16 session-state files filtered, 6 real files surfaced.
**Evidence:**
- `agents/audit/audit.sh` filter regex covers 11 distinct session-state paths (T-1392 fix)
- `tests/unit/audit_session_state_filter.bats` — 3 tests, all pass
- Live audit verification: `[WARN] 6 real file(s) modified (16 session-state file(s) ignored)` — signal preserved, noise removed
- No regression: clean repo still reports clean

## Verification

# Syntax check on the audit script
bash -n agents/audit/audit.sh
# New test file exists
test -f tests/unit/audit_session_state_filter.bats
# Run ONLY the new bats file directly (NOT `fw test unit` which runs the full
# suite and times out the verification gate)
bats tests/unit/audit_session_state_filter.bats 2>&1 | grep -q "^ok 3"

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

### 2026-04-23T11:01:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1392-audit-ignore-session-state-files-in-unco.md
- **Context:** Initial task creation

### 2026-04-23T11:16:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-45da4803
- **Timestamp:** 2026-06-02T14:57:09Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Agent)** — Filter set covers: `.context/working/{watchtower.*,session.yaml,focus.yaml,.session-metrics.yaml,.tool-counter,.edit-counter,.budget-status,.gate-bypass-log.yaml,.approval-notified}`, `.context/audits
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/project/metrics-history.yaml in: Filter set covers: `.context/working/{watchtower.*,session.yaml,focus.yaml,.session-metrics.yaml,.tool-counter,.edit-counter,.budget-status,.gate-bypa`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 7
     - evidence: `bats tests/unit/audit_session_state_filter.bats 2>&1 | grep -q "^ok 3"`
