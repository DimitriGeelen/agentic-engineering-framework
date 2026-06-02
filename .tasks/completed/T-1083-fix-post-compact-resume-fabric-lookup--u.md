---
id: T-1083
name: "Fix post-compact-resume fabric lookup — uses PROJECT_ROOT path, fails silently on consumers"
description: >
  Fix post-compact-resume fabric lookup — uses PROJECT_ROOT path, fails silently on consumers

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T08:45:08Z
last_update: 2026-04-11T08:46:18Z
date_finished: 2026-04-11T08:46:18Z
---

# T-1083: Fix post-compact-resume fabric lookup — uses PROJECT_ROOT path, fails silently on consumers

## Context

`agents/context/post-compact-resume.sh:141` calls `$PROJECT_ROOT/agents/fabric/fabric.sh overview` to inject fabric context. In consumer projects `PROJECT_ROOT` is the consumer and `agents/fabric/fabric.sh` lives at `$FRAMEWORK_ROOT` (which resolves to `.agentic-framework/`). The call silently fails (`2>/dev/null`) and consumer sessions get no fabric context on resume. Same L-003 class as T-1078.

## Acceptance Criteria

### Agent
- [x] `post-compact-resume.sh` uses `$FRAMEWORK_ROOT/agents/fabric/fabric.sh` (not `$PROJECT_ROOT`)
- [x] Fabric condition still guards on consumer `.fabric/subsystems.yaml` existence
- [x] Verified consumer projects do have .fabric/ directories (tested on 050-email-archive)

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
grep -q 'FRAMEWORK_ROOT/agents/fabric/fabric.sh' agents/context/post-compact-resume.sh
! grep -q 'PROJECT_ROOT/agents/fabric/fabric.sh' agents/context/post-compact-resume.sh

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

### 2026-04-11T08:45:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1083-fix-post-compact-resume-fabric-lookup--u.md
- **Context:** Initial task creation

### 2026-04-11T08:46:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-772f8c8e
- **Timestamp:** 2026-06-02T14:55:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Fabric condition still guards on consumer `.fabric/subsystems.yaml` existence
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/subsystems.yaml in: Fabric condition still guards on consumer `.fabric/subsystems.yaml` existence`
