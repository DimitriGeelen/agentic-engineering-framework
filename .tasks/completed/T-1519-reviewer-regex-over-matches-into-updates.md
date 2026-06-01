---
id: T-1519
name: "Reviewer regex over-matches into Updates entries below verdict block"
description: >
  Reviewer regex over-matches into Updates entries below verdict block

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-26T21:20:17Z
last_update: 2026-04-26T21:23:42Z
date_finished: 2026-04-26T21:23:42Z
---

# T-1519: Reviewer regex over-matches into Updates entries below verdict block

## Context

`lib/reviewer/static_scan.py:691` defines `_VERDICT_SECTION_RE` with terminator `(?=^## |\Z)`. The terminator only stops at H2 (`## `) or end-of-string. When `update-task.sh` later appends an `### timestamp` (H3) Updates entry at EOF — which it does because reviewer writes the verdict at EOF — a subsequent re-scan rewrites the verdict block and silently nukes the H3 entries below. Captured in `feedback-stream.yaml` as `kind: rendering_concern` (commit 27fccc5b3).

Fix: tighten the terminator to `(?=^#{2,} |\Z)` so the regex stops at H2 OR H3 (`## ` or `### ` or any deeper). The verdict block stays bounded; subsequent Updates entries survive re-scan.

## Acceptance Criteria

### Agent
- [x] `_VERDICT_SECTION_RE` terminates at any markdown header level ≥ H2 (`^#{2,} ...`), not just H2
- [x] Re-running `fw reviewer T-XXX` on a task that has `### timestamp` entries below the verdict block preserves those entries
- [x] Existing first-scan behaviour unchanged (verdict still written at EOF when no prior verdict)
- [x] Unit/regression coverage: a test exercises the verdict-replacement preserving content below the block

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.

# Regex updated to stop at any heading ≥ H2
grep -q "#{2,}" lib/reviewer/static_scan.py
# Regression test exists and passes
test -f tests/unit/test_reviewer_verdict_preserves_updates.py
python3 -m pytest tests/unit/test_reviewer_verdict_preserves_updates.py -q 2>&1 | tail -3 | grep -qE "passed|ok"

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

### 2026-04-26T21:20:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1519-reviewer-regex-over-matches-into-updates.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-56a01af5
- **Timestamp:** 2026-04-26T21:23:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-26T21:23:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Regex fix + 3 regression tests + sanity-inverse confirmed + live smoke verified
