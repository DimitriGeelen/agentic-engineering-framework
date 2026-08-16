---
id: T-880
name: "Implement install pipeline auto-remediation — git hooks, identity, baseline,
  messaging (T-877)"
description: >
  Implement install pipeline auto-remediation — git hooks, identity, baseline, messaging
  (T-877)

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-05T06:47:22Z
last_update: '2026-08-16T22:25:42Z'
date_finished: 2026-04-05T06:51:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-880: Implement install pipeline auto-remediation — git hooks, identity, baseline, messaging (T-877)

## Context

Implements the 5 fixable failure modes from T-877 inception research. See `docs/reports/T-877-install-pipeline.md`.

## Acceptance Criteria

### Agent
- [x] F2: install.sh post-install messaging includes `cd` guidance
- [x] F3: fw init auto-installs git hooks
- [x] F4: fw init inherits git identity from global config
- [x] F5: fw init auto-creates enforcement baseline
- [x] F6: Post-init message mentions onboarding tasks and agent startup
- [x] Vendored copies synced
- [x] Integration tests pass (3/3)

<!-- T-1462: rubber-stamp converted to mechanical verification.
     Original Steps required a human to run fw init in a test dir + observe doctor output.
     Now: tmp-init verification in ## Verification asserts the F3/F5 outcomes structurally
     (git hooks installed, enforcement baseline file present). -->

## Verification

# T-1462: structural check — fw init on a fresh tmp dir produces hooks + enforcement baseline.
bash -c 'TMP=$(mktemp -d); cd "$TMP" && git init -q && /opt/999-Agentic-Engineering-Framework/bin/fw init "$TMP" >/dev/null 2>&1; rc=0; for f in .git/hooks/commit-msg .git/hooks/post-commit .git/hooks/pre-push .context/project/enforcement-baseline.sha256; do test -f "$TMP/$f" || rc=1; done; cd / && rm -rf "$TMP"; exit $rc'

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

### 2026-04-05T06:47:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-880-implement-install-pipeline-auto-remediat.md
- **Context:** Initial task creation

### 2026-04-05T06:51:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:27:24Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ccdb6353
- **Timestamp:** 2026-06-02T15:05:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`
