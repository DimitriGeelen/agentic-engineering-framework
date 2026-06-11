---
id: T-147
name: "Fix G-002: Auto-detect untracked handover open questions at resume + audit"
description: >
  Fix G-002: Auto-detect untracked handover open questions at resume + audit

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
related_tasks: []
created: 2026-02-18T10:08:20Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-02-18T10:11:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-147: Fix G-002: Auto-detect untracked handover open questions at resume + audit

## Context

G-002: Handover open questions are prose-only markdown, never auto-registered in gaps/tasks. Lost across sessions. See `.context/inbox/2026-02-18-sprechloop-gap-feedback.md`.

## Acceptance Criteria

- [x] Audit agent warns when handover has untracked open questions
- [x] Resume agent surfaces open questions with register prompt
- [x] Template placeholders ([TODO], [Question]) correctly filtered out

## Verification

# Audit check exists
grep -q "HANDOVER OPEN QUESTIONS" agents/audit/audit.sh
# Resume check exists
grep -q "Unresolved Open Questions" agents/resume/resume.sh
# Sprechloop audit detects untracked question
bash -c 'PROJECT_ROOT=/opt/001-sprechloop ./agents/audit/audit.sh 2>&1 > /tmp/audit-g002.txt; grep -q "open question.*no matching" /tmp/audit-g002.txt'

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

### 2026-02-18T10:08:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-147-fix-g-002-auto-detect-untracked-handover.md
- **Context:** Initial task creation

### 2026-02-18T10:11:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-98c1b0e3
- **Timestamp:** 2026-06-02T14:57:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
