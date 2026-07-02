---
id: T-1458
name: "Fix T-1455 inception 404 — workflow_type stuck on build, investigate fw task
  update --type persistence"
description: >
  Fix T-1455 inception 404 — workflow_type stuck on build, investigate fw task update
  --type persistence

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/observe/observe.sh, tests/unit/observe.bats]
related_tasks: []
created: 2026-04-25T13:16:45Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T13:20:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1458: Fix T-1455 inception 404 — workflow_type stuck on build, investigate fw task update --type persistence

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] T-1455 returns HTTP 200 at /inception/T-1455 (data fix landed)
- [x] Root cause identified: `fw note promote` hard-coded `--type build` with no override flag
- [x] `fw note promote` accepts `--type <type>` flag and forwards it to create-task.sh
- [x] Latent silent-failure bug in do_promote fixed (set -euo pipefail killed script before "not found" message)
- [x] 4 new bats tests in tests/unit/observe.bats — all 11 pass
- [x] Learning recorded (L-272)

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

# Shell commands that MUST pass before work-completed. One per line.
curl -sf "$(bin/fw watchtower url)/inception/T-1455" >/dev/null
bin/fw note promote --help 2>&1 | grep -q -- "--type"
bats tests/unit/observe.bats

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

### 2026-04-25T13:16:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1458-fix-t-1455-inception-404--workflowtype-s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b076509f
- **Timestamp:** 2026-06-02T14:57:37Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf "$(bin/fw watchtower url)/inception/T-1455" >/dev/null`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bin/fw note promote --help 2>&1 | grep -q -- "--type"`
### 2026-04-25T13:20:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
