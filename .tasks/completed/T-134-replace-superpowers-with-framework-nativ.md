---
id: T-134
name: Replace superpowers with framework-native behavioral rules and skills
description: >
  Strip superpowers/feature-dev plugin references. Add two behavioral rules to CLAUDE.md
  (verification before completion, hypothesis-driven debugging). Create two lightweight
  framework-native skills (/explore, /plan). Update template. Clean up start-work
  skill references.
status: work-completed
workflow_type: build
horizon:
owner: human
tags: []
related_tasks: []
created: 2026-02-17T23:31:32Z
last_update: '2026-08-16T22:24:29Z'
date_finished: 2026-02-17T23:41:25Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
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
  - ts: '2026-08-16T22:24:29Z'
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

# T-134: Replace superpowers with framework-native behavioral rules and skills

## Context

T-124 cycle 2 analysis revealed superpowers plugin was competing with framework governance — self-propagating skill chains, 1820-line plans for spike work, and over-planning. Deep evaluation showed feature-dev had the same problem. Decision: strip both, replace with lightweight behavioral rules + 2 framework-native skills.

Evidence: session transcript analysis of sprechloop cycle 2 (agent-a694e15).

## Acceptance Criteria

- [x] superpowers and feature-dev disabled in settings.json
- [x] All superpowers/feature-dev references removed from CLAUDE.md
- [x] All references removed from template (claude-project.md)
- [x] All references removed from start-work skill
- [x] Verification Before Completion behavioral rule added to CLAUDE.md + template
- [x] Hypothesis-Driven Debugging behavioral rule added to CLAUDE.md + template
- [x] /explore skill created (replaces brainstorming)
- [x] /plan skill created (replaces writing-plans)

## Verification

grep -qi 'superpowers\|feature-dev\|brainstorm\|writing-plans\|executing-plans' CLAUDE.md && exit 1 || true
grep -qi 'superpowers\|feature-dev\|brainstorm\|writing-plans\|executing-plans' lib/templates/claude-project.md && exit 1 || true
test -f .claude/commands/explore.md
test -f .claude/commands/plan.md
grep -q 'Verification Before Completion' CLAUDE.md
grep -q 'Hypothesis-Driven Debugging' CLAUDE.md

## Updates

### 2026-02-17T23:31:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-134-replace-superpowers-with-framework-nativ.md
- **Context:** Initial task creation

### 2026-02-17T23:41:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4185bdb1
- **Timestamp:** 2026-06-02T14:56:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
