---
id: T-1401
name: "T-1268 B3 follow-on: add /pending to Watchtower Govern nav"
description: >
  T-1268 B3 follow-on: add /pending to Watchtower Govern nav

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/shared.py]
related_tasks: []
created: 2026-04-23T14:16:42Z
last_update: 2026-04-23T14:18:09Z
date_finished: 2026-04-23T14:18:09Z
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
