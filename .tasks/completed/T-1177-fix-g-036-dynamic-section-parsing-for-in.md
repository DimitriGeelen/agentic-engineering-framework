---
id: T-1177
name: "Fix G-036: Dynamic section parsing for inception detail page — remove hardcoded allowlist"
description: >
  Fix G-036: Dynamic section parsing for inception detail page — remove hardcoded allowlist

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [web/blueprints/inception.py, web/templates/inception_detail.html]
related_tasks: []
created: 2026-04-12T17:26:30Z
last_update: 2026-04-13T06:28:11Z
date_finished: 2026-04-12T17:31:23Z
---

# T-1177: Fix G-036: Dynamic section parsing for inception detail page — remove hardcoded allowlist

## Context

G-036: `web/blueprints/inception.py:205-214` uses a hardcoded section allowlist. New sections (like `## Structural Upgrade`) are silently dropped. Fix: dynamically parse all `## Heading` sections from the task markdown body.

## Acceptance Criteria

### Agent
- [x] inception.py dynamically extracts all `## ` sections instead of hardcoded list
- [x] Inception detail page renders all sections from task file
- [x] Existing known sections still display correctly (backward compatible)
- [x] Web tests pass

### Human
- [x] [RUBBER-STAMP] Inception detail page shows all sections
  **Steps:**
  1. Open Watchtower at http://localhost:3000/inception/T-1146
  2. Verify sections like Problem Statement, Assumptions, Recommendation are visible
  **Expected:** All sections from task file visible on the page
  **If not:** Note which sections are missing

## Verification

# Dynamic section extraction exists
grep -q "_extract_all_sections" web/blueprints/inception.py
# Extra sections passed to template
grep -q "extra_sections" web/blueprints/inception.py
# Template renders extra sections dynamically
grep -q "extra_sections" web/templates/inception_detail.html
# Page loads without errors
curl -sf http://localhost:3000/inception/T-1146 | grep -q "section-card"

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

### 2026-04-12T17:26:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1177-fix-g-036-dynamic-section-parsing-for-in.md
- **Context:** Initial task creation

### 2026-04-12T17:31:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c7bd3ec6
- **Timestamp:** 2026-06-02T14:55:42Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `curl -sf http://localhost:3000/inception/T-1146 | grep -q "section-card"`
