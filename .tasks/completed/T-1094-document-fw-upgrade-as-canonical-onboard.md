---
id: T-1094
name: "Document fw upgrade as canonical onboarding command + clarify what it actually
  does (G-025)"
description: >
  Surface fw upgrade in CLAUDE.md, fw doctor output, and a new docs/consumer-project-setup.md
  as the canonical answer to 'set up the framework in this project'. Document exactly
  what it does (shim migration, governance refresh, vendored script sync, version
  pin) so agents stop assuming it copies framework files into a per-project directory.
  Origin: G-025. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: [T-1093]
created: 2026-04-11T12:15:33Z
last_update: '2026-08-16T22:24:22Z'
date_finished: 2026-04-12T07:27:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1094: Document fw upgrade as canonical onboarding command + clarify what it actually does (G-025)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw upgrade` documented in CLAUDE.md Quick Reference table
- [x] CLAUDE.md §fw CLI section mentions upgrade with description
- [x] Description clarifies upgrade does NOT copy framework code into
      the consumer project

## Verification

grep -q "fw upgrade" CLAUDE.md
grep -q "Upgrade consumer" CLAUDE.md

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

### 2026-04-11T12:15:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1094-document-fw-upgrade-as-canonical-onboard.md
- **Context:** Initial task creation

### 2026-04-12T07:25:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:27:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-92b75f2e
- **Timestamp:** 2026-06-02T14:55:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `consumer project`
