---
id: T-1402
name: "RCA audit.sh python traceback at line 108 — NoneType replace"
description: >
  RCA audit.sh python traceback at line 108 — NoneType replace

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004, tests/unit/audit_null_timestamp.bats]
related_tasks: []
created: 2026-04-23T14:44:13Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T14:51:55Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1402: RCA audit.sh python traceback at line 108 — NoneType replace

## Context

Pre-push audit in handover S-2026-0423-1623 emitted:
```
Traceback (most recent call last):
  File "<stdin>", line 108, in <module>
AttributeError: 'NoneType' object has no attribute 'replace'
```

Root cause: `agents/audit/audit.sh:3167,3180` (METRICS_EOF heredoc lines 107+120 from start at 3062 → `<stdin>:108` within the heredoc). The code uses `ts_str = e.get("timestamp", "")` which returns **None** (not `""`) when YAML has an explicit null value (`timestamp:` or `timestamp: null`). `None.replace("Z", "+00:00")` raises `AttributeError`, which is NOT caught by `except (ValueError, TypeError)`. Likely trigger: a partial write to `metrics-history.yaml` during the first push attempt (race with second pre-push audit).

Also at risk: line 3192 `sorted(..., key=lambda x: x.get("timestamp", ""))` — Python 3 cannot compare `None` with `str`, so a null timestamp would raise `TypeError` there too.

## Acceptance Criteria

### Agent
- [x] `audit.sh` defends against `timestamp: None` in metrics-history entries — None does not raise an uncaught exception
- [x] All three call sites (lines ~3167, ~3180, sort key ~3192) handle None timestamps gracefully
- [x] Audit runs cleanly against a corrupted metrics-history.yaml fixture (null timestamp entry present)
- [x] Regression test in tests/unit/ covers the None-timestamp case

## Verification

# Run audit clean on current repo
bash agents/audit/audit.sh >/tmp/t1402-audit.out 2>&1; grep -qv "Traceback" /tmp/t1402-audit.out && ! grep -q "NoneType" /tmp/t1402-audit.out
# Run regression test
bats tests/unit/audit_null_timestamp.bats

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

### 2026-04-23T14:44:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1402-rca-auditsh-python-traceback-at-line-108.md
- **Context:** Initial task creation

### 2026-04-23T14:51:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a9de58e9
- **Timestamp:** 2026-06-02T14:57:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
