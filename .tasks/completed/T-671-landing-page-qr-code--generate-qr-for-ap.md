---
id: T-671
name: "Landing page QR code — generate QR for /approvals URL on Watchtower dashboard"
description: >
  Landing page QR code — generate QR for /approvals URL on Watchtower dashboard

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-28T19:41:32Z
last_update: 2026-04-13T06:28:08Z
date_finished: 2026-03-28T19:46:03Z
---

# T-671: Landing page QR code — generate QR for /approvals URL on Watchtower dashboard

## Context

Add a QR code to the Watchtower landing page that links to `/approvals` for quick mobile access. Uses a JavaScript QR library (no server dependency). Complements T-667 (mobile review) and T-634 (review URL + QR in terminal).

## Acceptance Criteria

### Agent
- [x] Landing page shows a QR code linking to the `/approvals` page
- [x] QR code uses the LAN IP address (not localhost) for cross-device access
- [x] QR is generated server-side via Python qrcode (no external API, works offline)

### Human
- [x] [RUBBER-STAMP] Scan QR with phone and verify it opens /approvals
  **Steps:**
  1. Start Watchtower: `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve`
  2. Open `http://localhost:3000/` in desktop browser
  3. Scan the QR code with a phone camera
  **Expected:** Phone browser opens the approvals page on the LAN IP
  **If not:** Check if the QR URL is correct (hover to see tooltip)

## Verification

grep -q 'qr_approvals' web/blueprints/core.py
grep -q 'Mobile Approvals' web/templates/cockpit.html

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

### 2026-03-28T19:41:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-671-landing-page-qr-code--generate-qr-for-ap.md
- **Context:** Initial task creation

### 2026-03-28T19:46:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c0a7bfe1
- **Timestamp:** 2026-06-02T15:04:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
