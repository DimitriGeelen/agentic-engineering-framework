---
id: T-314
name: "Fix CLAUDE.md template — add missing 7 governance sections"
description: >
  Consumer CLAUDE.md template (lib/templates/claude-project.md or inline in init.sh)
  missing 7 of 18 major sections: authority model, error escalation, budget mgmt,
  sub-agent dispatch protocol, plan prohibition, behavioral rules, component fabric.
  ~70%% governance loss. Update template to include all governance sections. Source:
  T-306 investigation, Agent 5 findings.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-04T19:27:14Z
last_update: '2026-08-16T22:25:27Z'
date_finished: 2026-03-04T20:39:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:27Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-314: Fix CLAUDE.md template — add missing 7 governance sections

## Context

T-306 inception found consumer CLAUDE.md template missing ~70% governance. Gap analysis identified 5 entirely missing sections and 6 incomplete subsections. Fix: update `lib/templates/claude-project.md`.

## Acceptance Criteria

### Agent
- [x] Component Fabric section added (commands, cards, when to use)
- [x] Plan Mode Prohibition section added (prohibits EnterPlanMode, directs to /plan)
- [x] Auto-Restart section added (T-179 signal flow, safety)
- [x] Autonomous Mode Boundaries added to Behavioral Rules (initiative vs authority)
- [x] Agent/Human AC Split added to Behavioral Rules (T-193 partial-complete)
- [x] Inception Discipline updated with C-001 research artifact and dialogue log rules
- [x] Working with Tasks updated with structural flaws subsection and blast-radius
- [x] Session Start Protocol updated with manual compaction section
- [x] Quick Reference updated with Fabric commands and auto-restart row
- [x] Sub-Agent Dispatch Protocol updated with dispatch patterns
- [x] Verification Before Completion updated with Agent AC distinction

## Verification

# All 5 missing sections present
grep -q "## Component Fabric" lib/templates/claude-project.md
grep -q "## Plan Mode Prohibition" lib/templates/claude-project.md
grep -q "## Auto-Restart" lib/templates/claude-project.md
grep -q "### Autonomous Mode Boundaries" lib/templates/claude-project.md
grep -q "### Agent/Human AC Split" lib/templates/claude-project.md
# Key governance content present
grep -q "Research artifact first" lib/templates/claude-project.md
grep -q "blast-radius" lib/templates/claude-project.md
grep -q "structural flaws" lib/templates/claude-project.md
grep -q "Manual compaction" lib/templates/claude-project.md

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

### 2026-03-04T19:27:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-314-fix-claudemd-template--add-missing-7-gov.md
- **Context:** Initial task creation

### 2026-03-04T20:32:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T20:39:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-89027a8d
- **Timestamp:** 2026-06-02T15:02:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
