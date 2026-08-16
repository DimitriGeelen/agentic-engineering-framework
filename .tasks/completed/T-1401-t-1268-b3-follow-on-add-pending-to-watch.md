---
id: T-1401
name: "T-1268 B3 follow-on: add /pending to Watchtower Govern nav"
description: >
  T-1268 B3 follow-on: add /pending to Watchtower Govern nav

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/shared.py]
related_tasks: []
created: 2026-04-23T14:16:42Z
last_update: '2026-08-16T22:24:31Z'
date_finished: 2026-04-23T14:18:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
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
  - ts: '2026-08-16T22:24:31Z'
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

# T-1401: T-1268 B3 follow-on: add /pending to Watchtower Govern nav

## Context

T-1400 shipped the /pending page but without a Watchtower nav link, humans
would only discover it via URL or `fw doctor`. Add a "Pending" entry to the
Govern group in NAV_GROUPS so it appears in the dropdown.

## Acceptance Criteria

### Agent
- [x] `web/shared.py` `NAV_GROUPS` Govern group contains `("Pending", "pending.pending_page", None)`
- [x] Watchtower restarts cleanly with the new nav entry
- [x] `/pending` page still responds HTTP 200 with the nav link present in the rendered base template

## Verification

python3 -m py_compile web/shared.py
grep -q 'pending.pending_page' web/shared.py
_t=$(mktemp); curl -sf "$(bin/fw watchtower url)/pending" >"$_t" 2>&1; _r=$?; grep -q "Pending Updates" "$_t"; _g=$?; rm -f "$_t"; [ "$_r" -eq 0 ] && [ "$_g" -eq 0 ]
# Nav link should appear in the rendered HTML
_t=$(mktemp); curl -sf "$(bin/fw watchtower url)/pending" >"$_t" 2>&1; grep -q 'href="/pending"' "$_t"; _r=$?; rm -f "$_t"; [ "$_r" -eq 0 ]

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

### 2026-04-23T14:16:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1401-t-1268-b3-follow-on-add-pending-to-watch.md
- **Context:** Initial task creation

### 2026-04-23T14:18:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-45e9dc6a
- **Timestamp:** 2026-06-02T14:57:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`
