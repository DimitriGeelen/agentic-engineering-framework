---
id: T-340
name: "Create /write skill for voice-calibrated content"
description: >
  Create .claude/commands/write.md skill that reads docs/style-guide.md and task ACs,
  produces voice-calibrated drafts. Design from T-338 style anchor agent.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-08T08:37:32Z
last_update: '2026-06-11T22:24:19Z'
date_finished: 2026-03-08T08:48:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
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

# T-340: Create /write skill for voice-calibrated content

## Context

Design from T-338 style anchor agent analysis. Skill follows the same pattern as `/plan` — reads a reference file, reads the task, produces an artifact.

## Acceptance Criteria

### Agent
- [x] `.claude/commands/write.md` exists and is recognized as a skill
- [x] Skill references `docs/style-guide.md` as voice source
- [x] Skill includes self-check step with mechanical tests from style guide
- [x] Skill follows existing skill patterns (prerequisites, workflow steps, rules)

### Human
- [x] Skill produces acceptable voice-calibrated output when invoked on a content task

## Verification

test -f .claude/commands/write.md
grep -q "style-guide.md" .claude/commands/write.md
grep -q "Self-Check" .claude/commands/write.md
grep -q "Prerequisites" .claude/commands/write.md

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

### 2026-03-08T08:37:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-340-create-write-skill-for-voice-calibrated-.md
- **Context:** Initial task creation

### 2026-03-08T08:47:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T08:48:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-19d379d3
- **Timestamp:** 2026-06-02T15:02:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
