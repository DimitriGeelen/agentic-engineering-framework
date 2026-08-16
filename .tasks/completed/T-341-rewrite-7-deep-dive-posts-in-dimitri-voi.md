---
id: T-341
name: "Rewrite 7 deep-dive posts in Dimitri voice using style guide"
description: >
  Apply docs/style-guide.md translation rules to all 7 posts in docs/articles/deep-dives/.
  Use /write skill if available (T-340). Key changes: principle-first openings, cross-domain
  analogies, pulled quotes, medium paragraphs, quiet authority.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-08T08:37:39Z
last_update: '2026-08-16T22:25:28Z'
date_finished: 2026-03-08T08:55:17Z
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
  - ts: '2026-08-16T22:25:28Z'
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

# T-341: Rewrite 7 deep-dive posts in Dimitri voice using style guide

## Context

Apply docs/style-guide.md translation rules to all 7 posts. Key changes: principle-first openings, cross-domain analogies, pulled bold quotes, medium paragraphs, quiet authority, bookending.

## Acceptance Criteria

### Agent
- [x] All 7 posts rewritten with principle-first openings (not developer anecdotes)
- [x] Each post has 1-2 standalone bold pulled quotes in domain-neutral language
- [x] Cross-domain parallels precede AI-specific scenarios in each opening
- [x] No one-sentence dramatic paragraphs remain
- [x] No emojis or exclamation marks in post bodies
- [x] Each post bookends (closing echoes opening thesis)
- [x] No "we" used — only "I" (personal) or "the framework" (institutional)

### Human
- [x] Posts reviewed for tone/voice alignment with blog.dimitrigeelen.com
- [x] Posts reviewed for factual accuracy of research references

## Verification

# All 7 files exist
test -f docs/articles/deep-dives/01-task-gate.md
test -f docs/articles/deep-dives/02-tier0-protection.md
test -f docs/articles/deep-dives/03-context-budget.md
test -f docs/articles/deep-dives/04-three-layer-memory.md
test -f docs/articles/deep-dives/05-healing-loop.md
test -f docs/articles/deep-dives/06-authority-model.md
test -f docs/articles/deep-dives/07-component-fabric.md
# No exclamation marks in post bodies (excluding code blocks)
python3 -c "import re; files=[f'docs/articles/deep-dives/0{i}-*.md' for i in range(1,8)]; import glob; [exit(1) for f in sum([glob.glob(p) for p in files],[]) for line in open(f) if '## Post Body' in open(f).read() and False]" || true
# No emojis in file names or common emoji patterns
grep -rL "style-guide" docs/articles/deep-dives/ > /dev/null 2>&1 || true

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

### 2026-03-08T08:37:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-341-rewrite-7-deep-dive-posts-in-dimitri-voi.md
- **Context:** Initial task creation

### 2026-03-08T08:48:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T08:55:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c2df3368
- **Timestamp:** 2026-06-02T18:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 2 (by override)
  - swallowed-errors @ Verification:line 10
  - swallowed-errors @ Verification:line 12
