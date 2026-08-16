---
id: T-037
name: Create fw doctor health check command
description: >
  Validates framework installation path resolution version compatibility and project
  structure with PASS WARN FAIL output
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: [doctor, health-check, fw]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T23:45:32Z
last_update: '2026-08-16T22:24:17Z'
date_finished: 2026-02-14T09:04:14Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
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
  - ts: '2026-08-16T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-037: Create fw doctor health check command

## Design Record

**Implemented as:** Embedded `do_doctor` function in `bin/fw` (not a separate agent).

**Rationale:** Doctor is a diagnostic tool, not a workflow — doesn't need AGENT.md or task lifecycle. Embedding in fw keeps it simple and always available.

**Checks performed (7):**
1. Framework installation (agents/ and FRAMEWORK.md exist)
2. .framework.yaml (only when running as shared tooling)
3. Version pinning match
4. Task directories (.tasks/active, .tasks/completed)
5. Context directory (.context/)
6. Git hooks (commit-msg and pre-push)
7. Agent scripts executable

**Exit codes:** 0 = pass/warnings-only, 2 = failures

## Updates

### 2026-02-14T09:04:14Z — absorbed-into-T-033 [claude-code]
- **Action:** T-037 was implemented as part of T-033 (fw CLI wrapper)
- **Context:** Doctor is embedded in bin/fw, tested and working. 7 health checks, correct exit codes.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a268a0e1
- **Timestamp:** 2026-06-02T14:54:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
