---
id: T-631
name: "Human AC review via clickable URL + QR code — fw task review command"
description: >
  Human AC review via clickable URL + QR code — fw task review command

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-26T22:20:03Z
last_update: 2026-04-13T06:28:08Z
date_finished: 2026-03-27T18:30:38Z
---

# T-631: Human AC review via clickable URL + QR code — fw task review command

## Context

Replace T-608's complex Tier 0 approval surface with a simple mechanism: print a clickable URL (+ QR code for mobile) that opens the Watchtower task page at the Human AC section. Human clicks, reviews, checks boxes. Agent polls for completion. Replaces terminal switching, long copy-paste commands, and the entire 4-child-task T-608 approach.

Prerequisites: Watchtower AC checkboxes (T-620), toggle-ac API, Python qrcode 7.4.2.

## Acceptance Criteria

### Agent
- [x] `fw task review T-XXX` command exists and runs
- [x] Prints clickable URL to Watchtower task page with #human-ac anchor
- [x] Prints QR code (using python3 qrcode library) encoding the same URL
- [x] Uses configurable base URL (localhost:3000 default, WATCHTOWER_URL env override)
- [x] Watchtower task template has `id="human-ac"` anchor on Human AC section
- [x] `bash -n` passes on bin/fw
- [x] `--poll` flag: polls task file every 5s, exits 0 when all Human ACs checked (timeout 10min)
- [x] URL opens correct task page in browser (reclassified from Human RUBBER-STAMP per T-954)

### Human
- [x] [RUBBER-STAMP] QR code scans and opens same page on phone
  **Steps:**
  1. Scan the terminal QR code with phone camera
  2. Open the link
  **Expected:** Watchtower task page loads on phone
  **If not:** Check if phone is on same network, try prod URL

## Verification

bash -n lib/review.sh 2>/dev/null || bash -n lib/tasks.sh
bin/fw task review T-631 --help 2>&1 | grep -q "review"
python3 -c "import qrcode; print('ok')"
curl -sf http://localhost:3000/task/T-631 | grep -q "T-631"

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

### 2026-03-26T22:20:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-631-human-ac-review-via-clickable-url--qr-co.md
- **Context:** Initial task creation

### 2026-03-27T17:34:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-03-27T18:30:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8d1a414e
- **Timestamp:** 2026-06-02T15:04:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw task review T-631 --help 2>&1 | grep -q "review"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -sf http://localhost:3000/task/T-631 | grep -q "T-631"`
