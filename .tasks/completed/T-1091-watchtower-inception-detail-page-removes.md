---
id: T-1091
name: "Watchtower inception detail page removes rationale hint 500-char truncation"
description: >
  T-1084 follow-up: web/blueprints/inception.py:221-222 truncates the Recommendation
  section to 500 chars for the rationale textarea hint. Humans recording an inception
  decision get incomplete rationale pre-populated (last fragment cut with '...').
  The detail page is the full view for a single task — no reason to truncate. Remove
  the limit so the full Recommendation pre-populates the textarea. approvals.py 200-char
  limit in its list view is fine and not touched.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-11T10:48:54Z
last_update: '2026-08-16T22:24:22Z'
date_finished: 2026-04-11T10:50:03Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
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
  - ts: '2026-08-16T22:24:22Z'
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

# T-1091: Watchtower inception detail page removes rationale hint 500-char truncation

## Context

T-1084 follow-up. `web/blueprints/inception.py:221-222` truncates the Recommendation section to 500 chars before pre-populating the rationale textarea. Humans recording a decision get a fragment with "..." cut off the end. The detail page shows ONE task — no rationale for truncation. Remove the limit. The list-view truncation in `approvals.py:146-147` (200 chars) is appropriate for a list and is not touched.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/inception.py` no longer truncates `rationale_hint` at 500 chars — the full Recommendation section pre-populates the textarea.
- [x] Mirrored to `.agentic-framework/web/blueprints/inception.py`.
- [x] `approvals.py` 200-char list-view hint is preserved (not in scope).

## Verification

python3 -c "src=open('web/blueprints/inception.py').read(); assert 'rationale_hint[:497]' not in src, 'truncation still present'; assert '> 500' not in src.split('rationale_hint')[1][:500] if 'rationale_hint' in src else True; print('ok')"
python3 -c "src=open('.agentic-framework/web/blueprints/inception.py').read(); assert 'rationale_hint[:497]' not in src, 'mirror truncation still present'; print('ok')"
python3 -c "src=open('web/blueprints/approvals.py').read(); assert 'hint[:197]' in src, 'approvals list-view hint should be preserved'; print('ok')"

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

### 2026-04-11T10:48:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1091-watchtower-inception-detail-page-removes.md
- **Context:** Initial task creation

### 2026-04-11T10:50:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7a4a525f
- **Timestamp:** 2026-06-02T14:55:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
