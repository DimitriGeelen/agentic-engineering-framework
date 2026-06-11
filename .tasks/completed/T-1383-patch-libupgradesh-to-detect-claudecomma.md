---
id: T-1383
name: "Patch lib/upgrade.sh to detect .claude/commands/resume.md template drift —
  close G-056"
description: >
  Patch lib/upgrade.sh to detect .claude/commands/resume.md template drift — close
  G-056

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-22T19:48:45Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-22T19:53:20Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 5
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=5
      (body:class-neutral); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1383: Patch lib/upgrade.sh to detect .claude/commands/resume.md template drift — close G-056

## Context

Closes G-056. `lib/upgrade.sh:694-709` preserves existing `.claude/commands/resume.md` without comparing against current template output. T-1378 B1's template fix does not propagate to existing consumers. Fix: extract heredoc to `lib/templates/resume-md.md`, have init.sh read from it (falling back to inline heredoc if template file missing), add drift detection in upgrade.sh that backs up + refreshes when template differs from consumer file.

## Acceptance Criteria

### Agent
- [x] `lib/templates/resume-md.md` exists with current resume.md template content
- [x] `lib/init.sh` reads from `lib/templates/resume-md.md` when present (falls back to inline heredoc)
- [x] `lib/upgrade.sh` detects drift between consumer's `.claude/commands/resume.md` and `lib/templates/resume-md.md`
- [x] On drift, upgrade writes `.bak` and refreshes
- [x] Smoke test: synthesize a stale resume.md, run `do_upgrade`, confirm file is refreshed + .bak left behind (verified 2026-04-22T21:51Z)
- [x] Round-trip: fresh init template then diff reports no drift for resume.md (verified 2026-04-22T21:51Z)

## Verification

test -f lib/templates/resume-md.md
grep -q 'watchtower.url' lib/templates/resume-md.md
grep -q 'templates/resume-md.md' lib/upgrade.sh
grep -qE 'templates/resume-md.md|resume_tmpl' lib/init.sh

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

### 2026-04-22T19:48:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1383-patch-libupgradesh-to-detect-claudecomma.md
- **Context:** Initial task creation

### 2026-04-22T19:53:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-58f9da00
- **Timestamp:** 2026-06-02T14:57:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
