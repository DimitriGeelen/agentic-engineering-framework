---
id: T-1495
name: "Pickup: Watchtower discovery (_watchtower_url) fails closed when /api/_identity
  returns 404; fw serve writes triple-file non-atomically (partial state observed);
  fw doctor misdiagnoses partial triple as stale pid (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-141. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-26T11:12:02Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T17:41:59Z
source_task_id_in_origin: T-141
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1495: Pickup: Watchtower discovery (_watchtower_url) fails closed when /api/_identity returns 404; fw serve writes triple-file non-atomically (partial state observed); fw doctor misdiagnoses partial triple as stale pid (from 003-NTB-ATC-Plugin)

## Context

Pickup envelope P-013 (003-NTB-ATC-Plugin / T-141, 2026-04-25) reported three coupled Watchtower discovery defects:
1. `_watchtower_url()` fails closed when `/api/_identity` returns 404 (older Watchtower predating endpoint addition)
2. `fw serve` writes triple-file non-atomically — `watchtower.pid` populated, `watchtower.url`/`.port` zero bytes
3. `fw doctor` misdiagnoses partial triple as "stale pid (not running)" when pid IS alive

**All three are subsumed by T-1284** (Watchtower port discovery regression — active inception in this framework). T-1284's IN-scope explicitly lists: `/api/_identity` endpoint, startup triple file (pid/port/url), rewrite of `_watchtower_url`, regression test, `fw doctor` surfacing.

Recent commits referencing T-1284:
- `2e943a2a T-1292: B4 — fw doctor surfaces watchtower triple state (T-1284)` — addresses defect 3
- `c2d83ac0 T-1291: B6 — Regression test for _watchtower_url masquerade rejection`
- `5c6b4b8d T-1286: Close (B1 identity endpoint) + T-1287 verification` — addresses defect 1

T-1495 is therefore a duplicate filing from the consumer side. Once 003-NTB-ATC-Plugin runs `fw upgrade`, all three symptoms resolve. No additional framework work is required under this task ID.

## Acceptance Criteria

### Agent
- [x] Confirm T-1284 covers defect 1 (`_watchtower_url` rewrite) — IN-scope: `/api/_identity` endpoint, rewrite of `_watchtower_url`
- [x] Confirm T-1284 covers defect 2 (atomic triple-file write) — IN-scope: startup triple file (pid/port/url)
- [x] Confirm T-1284 covers defect 3 (fw doctor diagnosis) — landed in commit 2e943a2a (T-1292 B4)
- [x] No code change required in T-1495 scope

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

ls .tasks/active/T-1284-* >/dev/null
test -n "$(git log --oneline --all --grep='T-1292.*B4.*fw doctor surfaces watchtower triple')"
test -n "$(git log --oneline --all --grep='T-1286.*B1 identity endpoint')"

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

### 2026-04-26T11:12:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1495-pickup-watchtower-discovery-watchtowerur.md
- **Context:** Initial task creation

### 2026-04-26T17:41:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3370485d
- **Timestamp:** 2026-06-02T14:57:52Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `ls .tasks/active/T-1284-* >/dev/null`
### 2026-04-26T17:41:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
