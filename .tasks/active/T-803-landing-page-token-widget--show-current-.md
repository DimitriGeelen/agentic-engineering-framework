---
id: T-803
name: "Landing page token widget — show current session tokens on Watchtower dashboard"
description: >
  Add a token usage summary widget to the Watchtower landing page (/). Show current session token count, cache hit rate, and link to /costs. Quick integration using the costs blueprint parsing.

status: captured
workflow_type: build
owner: human
horizon: next
tags: [watchtower, tokens, observability]
components: [watchtower-web-ui]
related_tasks: [T-802, T-801, T-799]
created: 2026-04-03T19:17:34Z
last_update: 2026-04-12T09:26:19Z
date_finished: null
---

# T-803: Landing page token widget — show current session tokens on Watchtower dashboard

## Context

Follow-up from T-802 (Watchtower /costs page). Adds a compact token usage widget to the landing page cockpit. Uses `_load_all_sessions()` from costs blueprint.

## Acceptance Criteria

### Agent
- [x] `_get_token_usage()` helper added to `web/blueprints/core.py`
- [x] Token data passed to cockpit template context
- [x] Token widget renders on landing page showing current session tokens, total project tokens, cache hit rate
- [x] Widget links to `/costs` for full details
- [x] Landing page loads without errors

### Human
- [ ] [REVIEW] Token widget looks good on landing page
  **Steps:**
  1. Open http://192.168.10.107:3000/ in browser
  2. Look for token usage widget near the top of the page
  3. Verify it shows session tokens and links to /costs
  **Expected:** Compact widget with current session tokens, cache hit rate, link to /costs
  **If not:** Note what's missing or broken

## Verification

curl -sf http://localhost:3000/ -o /tmp/T-803-verify.html && grep -qi "token" /tmp/T-803-verify.html
python3 -c "from web.blueprints.core import _get_token_usage; print('OK')"

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

### 2026-04-03T19:17:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-803-landing-page-token-widget--show-current-.md
- **Context:** Initial task creation

### 2026-04-12T09:26:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)
