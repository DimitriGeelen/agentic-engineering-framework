---
id: T-851
name: "Linkable task references in handover session summary — clickable T-XXX links to Watchtower task pages"
description: >
  The 'Where We Are' session summary in handovers lists tasks like 'T-848 (Sync vendored...)' as plain text. These should be clickable links to the relevant Watchtower task pages (/tasks/T-XXX) and related documents (docs/reports/). Applies to both the handover markdown and the Watchtower /timeline view that renders handover summaries.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-04T15:17:20Z
last_update: 2026-04-04T21:59:11Z
date_finished: 2026-04-04T21:59:11Z
---

# T-851: Linkable task references in handover session summary — clickable T-XXX links to Watchtower task pages

## Context

Handover "Where We Are" section lists task IDs as plain text (e.g., "T-848 (Sync vendored...)").
These should be clickable links in Watchtower — both in /timeline cards and the handover detail view.
Two approaches: (1) generate markdown links in handover.sh, (2) auto-link T-XXX patterns in Watchtower rendering.
Approach (2) is more universal — auto-links work everywhere including task pages, approvals, etc.

## Acceptance Criteria

### Agent
- [x] Jinja filter or template macro auto-links T-XXX patterns to /tasks/T-XXX in Watchtower HTML
- [x] /timeline cards show clickable task links in session summaries
- [x] Handover "Where We Are" text has clickable T-XXX links when rendered in Watchtower
- [x] Task links in /timeline are clickable and navigate to correct task pages (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

python3 -c "from web.shared import linkify_tasks; assert '<a ' in linkify_tasks('T-849 fixed')"
curl -sf http://localhost:3000/timeline | grep -q "T-"

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

### 2026-04-04T15:17:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-851-linkable-task-references-in-handover-ses.md
- **Context:** Initial task creation

### 2026-04-04T17:55:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-04T21:59:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b790e9af
- **Timestamp:** 2026-06-02T15:05:14Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/timeline | grep -q "T-"`
