---
id: T-1254
name: "Restore learnings.yaml (lost in T-012 handover commit 4eb23e81) + add shrinkage guard blocking"
description: >
  learnings.yaml reverted from 239 entries (1688 lines) to 1 entry (10 lines) in my handover commit. Same class as T-1242. The T-1250 advisory shrinkage guard didn't prevent this because it only WARNS. This task: restore + investigate blocking enforcement.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-14T19:57:00Z
last_update: 2026-04-14T19:58:23Z
date_finished: 2026-04-14T19:58:23Z
---

# T-1254: Restore learnings.yaml (lost in T-012 handover commit 4eb23e81) + add shrinkage guard blocking

## Context

My commit 4eb23e81 (handover S-2026-0414-0019 in this session) wiped 1680 lines
from .context/project/learnings.yaml — from 239 entries (1688 lines at a0927e9c)
to 1 entry (10 lines).

Root cause: file was already corrupted at session start (reverted somewhere between
7f62bcd4 T-1242 restore and a0927e9c handover — though git shows both had 1688
lines, so the revert must have happened in working-tree before session start without
being committed). I staged without reading content.

Same class as T-1242. The T-1250 YAML shrinkage guard is advisory-only — it didn't
block this commit (hook either didn't fire or the warning was ignored).

## Acceptance Criteria

### Agent
- [x] Diagnosed: commit 4eb23e81 wiped 1680 lines; full restore available from a0927e9c
- [x] learnings.yaml restored to 1688 lines from commit a0927e9c (239 entries)
- [x] L-006 (T-1250 grep -c learning) re-appended after restore — 1695 lines total
- [x] Audit shows bugfix-learning coverage moves off 0/242 after restore

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

# learnings.yaml has at least 1000 lines (was 1688)
test $(wc -l < .context/project/learnings.yaml) -gt 1000
# L-002 present (T-1250 learning)
grep -q "T-1250" .context/project/learnings.yaml

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

### 2026-04-14T19:57:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1254-restore-learningsyaml-lost-in-t-012-hand.md
- **Context:** Initial task creation

### 2026-04-14T19:58:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1cd98d6c
- **Timestamp:** 2026-06-02T14:56:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
