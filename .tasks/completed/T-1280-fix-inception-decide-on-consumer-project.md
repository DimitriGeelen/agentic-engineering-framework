---
id: T-1280
name: "Fix inception decide on consumer projects — Watchtower Go/No-Go broken"
description: >
  Fix inception decide on consumer projects — Watchtower Go/No-Go broken

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-17T10:16:31Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-04-21T20:37:59Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1280: Fix inception decide on consumer projects — Watchtower Go/No-Go broken

## Context

**Superseded by T-1262** (2026-04-15). Same root cause: Watchtower Flask inherits `CLAUDECODE=1` from the Claude Code session, which triggers `lib/inception.sh` sovereignty guard meant for direct-in-session agent invocation. T-1262 added `--from-watchtower` bypass flag + subprocess env strip. This T-1280 was opened 2 days later without checking for the already-landed fix — L-237 (from T-1375 today) is the exact same pattern.

## Acceptance Criteria

### Agent
- [x] Verified T-1262 fix present in lib/inception.sh (--from-watchtower flag)
- [x] Verified web/blueprints/inception.py passes the flag
- [x] Verified web/subprocess_utils.py strips CLAUDECODE
- [x] T-1262 closed 2026-04-15 with 16/16 bats tests passing

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

grep -q "from-watchtower" lib/inception.sh
grep -q "from-watchtower" web/blueprints/inception.py
grep -q "CLAUDECODE" web/subprocess_utils.py
test -f .tasks/completed/T-1262-fix-inception-decide-sovereignty-gate--w.md

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

### 2026-04-17T10:16:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1280-fix-inception-decide-on-consumer-project.md
- **Context:** Initial task creation

### 2026-04-21T20:37:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-74a072e0
- **Timestamp:** 2026-06-02T14:56:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
