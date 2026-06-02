---
id: T-1081
name: "Fix fw gaps — missed T-397 rename from gaps.yaml to concerns.yaml"
description: >
  Fix fw gaps — missed T-397 rename from gaps.yaml to concerns.yaml

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T08:34:53Z
last_update: 2026-04-11T08:36:10Z
date_finished: 2026-04-11T08:36:10Z
---

# T-1081: Fix fw gaps — missed T-397 rename from gaps.yaml to concerns.yaml

## Context

T-397 renamed `.context/project/gaps.yaml` to `concerns.yaml`, and `agents/audit/audit.sh` was updated to try both paths. But `bin/fw gaps` still only looks at `gaps.yaml` and reports "No gaps register found" when 28 concerns exist. Users running `fw gaps` get wrong signal.

## Acceptance Criteria

### Agent
- [x] `bin/fw gaps` checks `concerns.yaml` first, falls back to `gaps.yaml`
- [x] Python block reads whichever file was found (handles both `concerns` and `gaps` keys)
- [x] `fw gaps` now lists 11 watching + 13 resolved concerns from concerns.yaml

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
# Lines starting with # are comments (skipped). Empty lines ignored.
grep -q 'concerns.yaml' bin/fw
bin/fw gaps 2>&1 | grep -q 'watching'

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

### 2026-04-11T08:34:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1081-fix-fw-gaps--missed-t-397-rename-from-ga.md
- **Context:** Initial task creation

### 2026-04-11T08:36:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-92e2f88a
- **Timestamp:** 2026-06-02T14:55:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw gaps 2>&1 | grep -q 'watching'`
